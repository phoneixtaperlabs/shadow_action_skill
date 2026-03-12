import Cocoa
import OSLog
import SwiftUI

// MARK: - DictationCoordinator

/// Orchestrates the full dictation lifecycle: ASR creation, audio capture,
/// transcription forwarding, RMS wiring, and window management.
///
/// Extracted from `ShadowActionSkillPlugin` to separate domain orchestration
/// from Flutter method-channel routing. (Cohesion)
///
/// `@MainActor` matches `WindowManager` and `DictationViewModel` — all
/// property mutations happen on the main thread. Heavy async work (actor-isolated
/// services) is awaited inside the methods, which hop off the main actor automatically.
@MainActor
final class DictationCoordinator {

    // MARK: - State

    private let logger: Logger
    private let audioCaptureService: AudioCaptureService
    private let coreAudioService: CoreAudioService

    /// `nonisolated` because init only assigns constants and nil optionals —
    /// no @MainActor-dependent work. Allows the plugin (nonisolated NSObject)
    /// to store this as a default property value.
    nonisolated init() {
        self.logger = Logger(subsystem: "shadow_action_skill", category: "DictationCoordinator")
        self.audioCaptureService = AudioCaptureService()
        self.coreAudioService = CoreAudioService()
    }

    private var asrService: (any ASRService)?
    private var transcriptionTask: Task<Void, Never>?
    private var rmsTask: Task<Void, Never>?
    private var silenceTask: Task<Void, Never>?

    /// RMS level below which the mic is considered silent (not picking up audio).
    /// Normalized scale: -60dB → 0.0, 0dB → 1.0. 0.02 ≈ -59dB — no signal at all.
    private static let micSilenceThreshold: Float = 0.02

    /// Seconds of mic-level silence before notifying Flutter.
    private static let micSilenceTimeoutSeconds: Double = 10.0

    /// Number of RMS frames sampled at session start to estimate ambient noise floor (~0.5s at 60fps).
    private static let calibrationFrameCount = 30
    /// RMS margin added above the noise floor to set the speaking threshold.
    private static let speakingMargin: Float = 0.10
    /// Upper bound on the calibrated speaking threshold — prevents a noisy environment from
    /// setting the threshold so high that speech never triggers the waveform.
    private static let maxSpeakingThreshold: Float = 0.35

    /// Whether a dictation session is currently active.
    var isActive: Bool { asrService != nil }

    // MARK: - Window Identifiers

    private static let dictationWindowID = "dictation"
    private static let deviceNotificationWindowID = "deviceNotification"

    // MARK: - Public API

    /// Start a dictation session: create ASR, start audio, wire streams, show UI.
    ///
    /// - Parameters:
    ///   - providerName: ASR provider identifier (e.g. "whisper").
    ///   - whisperModelName: Optional model filename override for the Whisper provider.
    /// - Throws: `DictationCoordinatorError` on validation failures, or underlying service errors.
    func start(providerName: String = "whisper", whisperModelName: String? = nil) async throws {
        guard !isActive else { throw DictationCoordinatorError.alreadyRunning }
        asrService = try await buildASRPipeline(provider: providerName, whisperModelName: whisperModelName)
        showDictationWindow()
        startRMSObserver()
        startMicSilenceTimer()
    }

    // MARK: - Pipeline Setup (Private)

    private func buildASRPipeline(provider: String, whisperModelName: String?) async throws -> any ASRService {
        guard let service = ASRServiceFactory.create(provider: provider, whisperModelName: whisperModelName) else {
            throw DictationCoordinatorError.unknownProvider(provider)
        }
        try await service.prepare()
        try await audioCaptureService.start()
        let transcriptionStream = try await service.startStreaming(audioBuffers: await audioCaptureService.bufferStream)
        startTranscriptionForwarding(from: transcriptionStream)
        return service
    }

    private func startTranscriptionForwarding(from stream: AsyncStream<TranscriptionResult>) {
        logger.info("[DictationCoordinator] Pipeline started, listening for transcriptions...")
        transcriptionTask = Task { [logger] in
            for await transcription in stream {
                logger.info("[DictationCoordinator] → Flutter: isFinal=\(transcription.isFinal), text=\"\(transcription.text)\"")
                await FlutterBridge.shared.send("onTranscription", arguments: transcription.flutterPayload)
            }
            logger.info("[DictationCoordinator] Transcription stream ended")
        }
    }

    private func startRMSObserver() {
        rmsTask = Task { [weak self, logger] in
            var calibrationSamples: [Float] = []
            var isCalibrated = false
            for await rms in await audioCaptureService.rmsStream {
                guard let self, !Task.isCancelled else { break }
                WindowManager.shared.dictationViewModel?.rmsLevel = CGFloat(rms)
                if !isCalibrated {
                    calibrationSamples.append(rms)
                    if calibrationSamples.count >= Self.calibrationFrameCount {
                        self.calibrateSpeakingThreshold(from: calibrationSamples, logger: logger)
                        isCalibrated = true
                    }
                }
                if rms > Self.micSilenceThreshold { self.resetMicSilenceTimer() }
            }
        }
    }

    private func calibrateSpeakingThreshold(from samples: [Float], logger: Logger) {
        let noiseFloor = samples.reduce(0, +) / Float(samples.count)
        let threshold = min(Self.maxSpeakingThreshold, noiseFloor + Self.speakingMargin)
        WindowManager.shared.dictationViewModel?.speakingThreshold = CGFloat(threshold)
        logger.info("[DictationCoordinator] Calibrated speakingThreshold=\(threshold) (noiseFloor=\(noiseFloor))")
    }

    /// Stop dictation: transition UI to thinking, tear down pipeline.
    func stop() async {
        // Transition UI to "Thinking ..."
        WindowManager.shared.dictationViewModel?.phase = .thinking

        // Stop silence detection
        silenceTask?.cancel()
        silenceTask = nil

        // Stop RMS stream
        rmsTask?.cancel()
        rmsTask = nil

        // Stop pipeline: audio first, then ASR so flushRemaining yields isFinal=true,
        // then wait for transcription forwarding to receive it and exit naturally.
        await audioCaptureService.stop()
        await asrService?.stopStreaming()
        await transcriptionTask?.value
        transcriptionTask = nil
        await asrService?.teardown()
        asrService = nil

        // Safety net: restore volume in case Flutter didn't. No-op if already restored.
        try? await coreAudioService.restoreSystemVolume()
    }

    /// Dismiss the dictation UI windows.
    func dismissUI() {
        closeDictationWindow()
    }

    // MARK: - System Output Volume

    /// Mute system output. Delegates to CoreAudioService.
    func muteSystemOutput() async throws {
        try await coreAudioService.muteSystemOutput()
    }

    /// Restore system output volume. No-op if not muted. Delegates to CoreAudioService.
    func restoreSystemVolume() async throws {
        try await coreAudioService.restoreSystemVolume()
    }

    /// Returns the default input device name, or `nil` if no device exists.
    func getDefaultInputDeviceName() async -> String? {
        let snapshot = await coreAudioService.getDevices()
        return snapshot.defaultInputDevice?.name
    }

    // MARK: - Dictation UI

    /// Show the dictation fail view. (Predictability — does one thing, no side effects)
    func showDictationFail() {
        DictationFailView.showWindow()
    }

    /// Dismiss the dictation fail view.
    func dismissDictationFail() {
        DictationFailView.dismissWindow()
    }

    /// Dismiss the device notification view.
    func dismissDeviceNotification() {
        WindowManager.shared.closeWindow(identifier: Self.deviceNotificationWindowID)
    }

    /// Show the audio device selection view.
    func showAudioDeviceSelect() {
        AudioDeviceSelectView.showWindow()
    }

    /// Dismiss the audio device selection view.
    func dismissAudioDeviceSelect() {
        AudioDeviceSelectView.dismissWindow()
    }

    // MARK: - Window Management (Private)

    private func showDictationWindow() {
        let config = WindowConfiguration(
            identifier: Self.dictationWindowID,
            size: .zero,
            position: .screen(.bottomCenter, offset: CGPoint(x: 0, y: 80)),
            style: .nonActivatingPanel,
            sizingMode: .fitContent,
            usePanel: true
        )
        WindowManager.shared.showWindow(configuration: config) {
            DictationView()
        }
    }

    private func closeDictationWindow() {
        WindowManager.shared.closeWindow(identifier: Self.dictationWindowID)
    }

    /// Show device notification with the given device name. Called from Flutter.
    func showDeviceNotification(deviceName: String) {
        let config = WindowConfiguration(
            identifier: Self.deviceNotificationWindowID,
            size: .zero,
            position: .screen(.bottomCenter, offset: CGPoint(x: 0, y: 130)),
            style: .nonActivatingPanel,
            sizingMode: .fitContent,
            usePanel: true
        )
        WindowManager.shared.showWindow(configuration: config) {
            DeviceNotificationView(deviceName: deviceName)
        }
    }

    // MARK: - Mic Silence Detection (Private)

    /// Start (or restart) the mic silence timer. Fires once after `micSilenceTimeoutSeconds`
    /// of near-zero RMS, then sends `onNoSpeechDetected` to Flutter.
    /// Reset by `resetMicSilenceTimer()` each time RMS exceeds the threshold.
    private func startMicSilenceTimer() {
        silenceTask?.cancel()
        silenceTask = Task { [weak self, logger] in
            try? await Task.sleep(for: .seconds(Self.micSilenceTimeoutSeconds))
            guard !Task.isCancelled else { return }

            logger.info("[DictationCoordinator] Mic silence detected after \(Self.micSilenceTimeoutSeconds)s")
            await FlutterBridge.shared.send("onNoSpeechDetected")

            // One-shot — don't keep firing.
            self?.silenceTask = nil
        }
    }

    /// Reset the mic silence timer because audio signal was detected.
    private func resetMicSilenceTimer() {
        startMicSilenceTimer()
    }
}
