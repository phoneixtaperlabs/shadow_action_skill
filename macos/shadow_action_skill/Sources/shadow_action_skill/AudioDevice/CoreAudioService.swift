import CoreAudio
import OSLog

// MARK: - CoreAudioService

/// Manages audio input device enumeration, selection, and change monitoring
/// via the CoreAudio Hardware Abstraction Layer (HAL).
///
/// ## Usage
/// ```swift
/// let service = CoreAudioService()
/// try await service.startMonitoring()
///
/// for await snapshot in service.deviceStream {
///     print("Devices: \(snapshot.inputDevices.map(\.name))")
///     print("Default: \(snapshot.defaultInputDevice?.name ?? "none")")
/// }
/// ```
///
/// ## Design Notes
/// - Actor isolation protects mutable state (device list, listener registrations).
/// - `AsyncStream<DeviceListSnapshot>` delivers changes — matches project convention. (Coupling)
/// - `ListenerContext` bridges CoreAudio's C callback into actor isolation.
/// - 50ms debounce coalesces rapid events (USB plug fires 2–3 within ~10ms).
actor CoreAudioService {

    // MARK: - State Machine

    /// Two-state lifecycle matching `AudioCaptureService` pattern.
    /// Single source of truth — eliminates impossible states. (Predictability)
    private enum State {
        case idle
        case monitoring(
            continuation: AsyncStream<DeviceListSnapshot>.Continuation,
            listenerContext: ListenerContext
        )
    }

    private var state: State = .idle

    // MARK: - Public Properties

    var isMonitoring: Bool {
        if case .monitoring = state { return true }
        return false
    }

    /// Stream of device snapshots. A new stream is created each time
    /// `startMonitoring()` is called. Finishes when `stopMonitoring()` is called.
    private(set) var deviceStream = AsyncStream<DeviceListSnapshot> { $0.finish() }

    // MARK: - Private Properties

    private let logger = Logger(subsystem: "shadow_action_skill", category: "CoreAudio")

    /// Debounce task for coalescing rapid CoreAudio property-change callbacks.
    private var pendingSnapshotTask: Task<Void, Never>?

    /// Whether we muted the output device. Guards against double-unmute. (Predictability)
    private var didMuteOutput = false

    /// CoreAudio property selectors monitored during active monitoring.
    private static let monitoredSelectors: [AudioObjectPropertySelector] = [
        kAudioHardwarePropertyDevices,
        kAudioHardwarePropertyDefaultInputDevice,
    ]

    // MARK: - Lifecycle

    /// Begin monitoring audio device changes.
    ///
    /// Registers CoreAudio property listeners for device-list and default-device changes.
    /// Immediately emits the current device snapshot, then emits on every change.
    ///
    /// - Throws: `CoreAudioError.alreadyMonitoring` if already active.
    /// - Throws: `CoreAudioError.osStatus` if listener registration fails.
    func startMonitoring() throws(CoreAudioError) {
        guard !isMonitoring else { throw .alreadyMonitoring }

        let (stream, continuation) = AsyncStream<DeviceListSnapshot>.makeStream()

        let context = ListenerContext(service: self)

        // Register listeners — roll back on partial failure.
        var registeredSelectors: [AudioObjectPropertySelector] = []
        do {
            for selector in Self.monitoredSelectors {
                try registerListener(selector: selector, context: context)
                registeredSelectors.append(selector)
            }
        } catch {
            for selector in registeredSelectors {
                unregisterListener(selector: selector, context: context)
            }
            continuation.finish()
            throw error
        }

        // Commit state only after all listeners are registered.
        self.deviceStream = stream
        self.state = .monitoring(continuation: continuation, listenerContext: context)

        // Emit initial snapshot immediately.
        let snapshot = captureSnapshot()
        continuation.yield(snapshot)

        logger.info("[CoreAudio] Monitoring started — \(snapshot.inputDevices.count) input device(s)")
    }

    /// Stop monitoring and finish the device stream.
    ///
    /// Safe to call in any state — no-op if not monitoring.
    func stopMonitoring() {
        guard case .monitoring(let continuation, let context) = state else { return }

        pendingSnapshotTask?.cancel()
        pendingSnapshotTask = nil

        for selector in Self.monitoredSelectors {
            unregisterListener(selector: selector, context: context)
        }

        // Prevent stale callbacks from reaching the actor.
        context.invalidate()
        continuation.finish()

        state = .idle
        logger.info("[CoreAudio] Monitoring stopped")
    }

    // MARK: - Device Queries

    /// Returns a snapshot of current input devices and the system default.
    /// Usable anytime — does not require active monitoring.
    func getDevices() -> DeviceListSnapshot {
        captureSnapshot()
    }

    /// Set the system default input device by persistent UID.
    ///
    /// - Parameter uid: The device UID (from `AudioDevice.uid`).
    /// - Throws: `CoreAudioError.deviceNotFound` or `.setDefaultFailed`.
    func setDefaultInputDevice(uid: String) throws(CoreAudioError) {
        let snapshot = captureSnapshot()
        guard let device = snapshot.inputDevices.first(where: { $0.uid == uid }) else {
            throw .deviceNotFound(identifier: uid)
        }
        try setDefaultInputDeviceProperty(device: device)
    }

    /// Set the system default input device by `AudioDeviceID`.
    ///
    /// - Parameter id: The device ID (from `AudioDevice.id`).
    /// - Throws: `CoreAudioError.deviceNotFound` or `.setDefaultFailed`.
    func setDefaultInputDevice(id: AudioDeviceID) throws(CoreAudioError) {
        let snapshot = captureSnapshot()
        guard let device = snapshot.inputDevices.first(where: { $0.id == id }) else {
            throw .deviceNotFound(identifier: "AudioDeviceID(\(id))")
        }
        try setDefaultInputDeviceProperty(device: device)
    }

    // MARK: - System Output Mute

    /// Mute the default output device via `kAudioDevicePropertyMute`.
    /// Uses the hardware mute flag for true silence (no residual audio).
    ///
    /// - Throws: `CoreAudioError.deviceNotFound` if no output device exists.
    /// - Throws: `CoreAudioError.osStatus` if the HAL call fails.
    func muteSystemOutput() throws(CoreAudioError) {
        let deviceID = queryDefaultOutputDeviceID()
        guard deviceID != kAudioObjectUnknown else {
            throw .deviceNotFound(identifier: "default output device")
        }

        try setOutputMute(deviceID: deviceID, muted: true)
        didMuteOutput = true
        logger.info("[CoreAudio] System output muted")
    }

    /// Unmute the default output device.
    /// No-op if not currently muted — safe to call in any state. (Predictability)
    ///
    /// - Throws: `CoreAudioError.deviceNotFound` if no output device exists.
    /// - Throws: `CoreAudioError.osStatus` if the HAL call fails.
    func restoreSystemVolume() throws(CoreAudioError) {
        guard didMuteOutput else { return }

        let deviceID = queryDefaultOutputDeviceID()
        guard deviceID != kAudioObjectUnknown else {
            throw .deviceNotFound(identifier: "default output device")
        }

        try setOutputMute(deviceID: deviceID, muted: false)
        didMuteOutput = false
        logger.info("[CoreAudio] System output unmuted")
    }

    // MARK: - Callback Bridge

    /// Called by `ListenerContext` when CoreAudio fires a property change.
    /// Debounces rapid events (50ms) before capturing and emitting a snapshot.
    fileprivate func handlePropertyChange() {
        pendingSnapshotTask?.cancel()
        pendingSnapshotTask = Task {
            // 50ms debounce — CoreAudio fires multiple events within ~10ms for a single physical change.
            try? await Task.sleep(for: .milliseconds(50))
            guard !Task.isCancelled else { return }

            guard case .monitoring(let continuation, _) = state else { return }
            let snapshot = captureSnapshot()
            continuation.yield(snapshot)

            logger.debug(
                "[CoreAudio] Device change — \(snapshot.inputDevices.count) device(s), default=\(snapshot.defaultInputDevice?.name ?? "none")"
            )
        }
    }

    // MARK: - Private: Set Default

    private func setDefaultInputDeviceProperty(device: AudioDevice) throws(CoreAudioError) {
        var deviceID = device.id
        var address = Self.globalPropertyAddress(
            selector: kAudioHardwarePropertyDefaultInputDevice
        )

        let status = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            UInt32(MemoryLayout<AudioDeviceID>.size),
            &deviceID
        )

        guard status == noErr else {
            throw .setDefaultFailed(deviceName: device.name, status: status)
        }

        logger.info("[CoreAudio] Default input device set to '\(device.name)'")
    }

    // MARK: - Private: Snapshot

    /// Queries CoreAudio for all input devices and the current default.
    /// All CoreAudio C calls are synchronous and fast (microsecond-scale).
    private func captureSnapshot() -> DeviceListSnapshot {
        let allDevices = queryAllInputDevices()
        let physicalDevices = allDevices.filter { !$0.isVirtual }
        let defaultID = queryDefaultInputDeviceID()
        let defaultDevice = physicalDevices.first { $0.id == defaultID }

        return DeviceListSnapshot(
            inputDevices: physicalDevices,
            defaultInputDevice: defaultDevice,
            timestamp: Date()
        )
    }

    // MARK: - Private: Device Enumeration

    /// Query all audio devices and return those with input capability.
    private func queryAllInputDevices() -> [AudioDevice] {
        var address = Self.globalPropertyAddress(selector: kAudioHardwarePropertyDevices)
        var dataSize: UInt32 = 0

        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize
        )
        guard status == noErr else {
            logger.warning("[CoreAudio] Failed to query device list size (status: \(status))")
            return []
        }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)

        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &dataSize, &deviceIDs
        )
        guard status == noErr else {
            logger.warning("[CoreAudio] Failed to query device list (status: \(status))")
            return []
        }

        return deviceIDs.compactMap { buildAudioDevice(id: $0) }
    }

    /// Build an `AudioDevice` from a device ID, returning `nil` if it has no input channels.
    private func buildAudioDevice(id deviceID: AudioDeviceID) -> AudioDevice? {
        let inputChannels = getInputChannelCount(deviceID: deviceID)
        guard inputChannels > 0 else { return nil }

        return AudioDevice(
            id: deviceID,
            name: getDeviceName(deviceID: deviceID),
            uid: getDeviceUID(deviceID: deviceID),
            inputChannelCount: inputChannels,
            isVirtual: isVirtualDevice(deviceID: deviceID)
        )
    }

    // MARK: - Private: CoreAudio Property Helpers

    private func queryDefaultInputDeviceID() -> AudioDeviceID {
        var address = Self.globalPropertyAddress(
            selector: kAudioHardwarePropertyDefaultInputDevice
        )
        var deviceID: AudioDeviceID = kAudioObjectUnknown
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)

        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil, &dataSize, &deviceID
        )
        return deviceID
    }

    private func getDeviceName(deviceID: AudioDeviceID) -> String {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioObjectPropertyName,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        guard let name = getCFStringProperty(deviceID: deviceID, address: &address) else {
            logger.warning("[CoreAudio] Failed to query device name (deviceID: \(deviceID))")
            return "Unknown Device"
        }
        return name as String
    }

    private func getDeviceUID(deviceID: AudioDeviceID) -> String {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        guard let uid = getCFStringProperty(deviceID: deviceID, address: &address) else {
            logger.warning("[CoreAudio] Failed to query device UID (deviceID: \(deviceID))")
            return ""
        }
        return uid as String
    }

    /// Reads a `CFStringRef` property from CoreAudio with correct ownership transfer.
    /// CoreAudio returns a +1 retained `CFStringRef`; `takeRetainedValue()` transfers
    /// ownership to Swift ARC so the string is released when it goes out of scope.
    private func getCFStringProperty(
        deviceID: AudioDeviceID,
        address: inout AudioObjectPropertyAddress
    ) -> CFString? {
        var stringRef: Unmanaged<CFString>?
        var dataSize = UInt32(MemoryLayout<CFString>.size)

        let status = AudioObjectGetPropertyData(
            deviceID, &address, 0, nil, &dataSize, &stringRef
        )
        guard status == noErr else { return nil }
        return stringRef?.takeRetainedValue()
    }

    /// Returns the total number of input channels via `kAudioDevicePropertyStreamConfiguration`.
    private func getInputChannelCount(deviceID: AudioDeviceID) -> Int {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioObjectPropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            deviceID, &address, 0, nil, &dataSize
        )
        guard status == noErr, dataSize > 0 else { return 0 }

        let bufferListMemory = UnsafeMutableRawPointer.allocate(
            byteCount: Int(dataSize),
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { bufferListMemory.deallocate() }

        status = AudioObjectGetPropertyData(
            deviceID, &address, 0, nil, &dataSize, bufferListMemory
        )
        guard status == noErr else { return 0 }

        let bufferList = bufferListMemory.assumingMemoryBound(to: AudioBufferList.self)
        return UnsafeMutableAudioBufferListPointer(bufferList)
            .reduce(0) { $0 + Int($1.mNumberChannels) }
    }

    /// Returns `true` if the device transport type is virtual or aggregate.
    private func isVirtualDevice(deviceID: AudioDeviceID) -> Bool {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyTransportType,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var transportType: UInt32 = 0
        var dataSize = UInt32(MemoryLayout<UInt32>.size)

        let status = AudioObjectGetPropertyData(
            deviceID, &address, 0, nil, &dataSize, &transportType
        )
        guard status == noErr else { return false }

        return transportType == kAudioDeviceTransportTypeAggregate
            || transportType == kAudioDeviceTransportTypeVirtual
    }

    // MARK: - Private: Output Volume

    /// Query the default output device. Mirrors `queryDefaultInputDeviceID()`. (Predictability)
    private func queryDefaultOutputDeviceID() -> AudioDeviceID {
        var address = Self.globalPropertyAddress(
            selector: kAudioHardwarePropertyDefaultOutputDevice
        )
        var deviceID: AudioDeviceID = kAudioObjectUnknown
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)

        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address, 0, nil, &dataSize, &deviceID
        )
        return deviceID
    }

    private func setOutputMute(deviceID: AudioDeviceID, muted: Bool) throws(CoreAudioError) {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyMute,
            mScope: kAudioObjectPropertyScopeOutput,
            mElement: kAudioObjectPropertyElementMain
        )
        var value: UInt32 = muted ? 1 : 0

        let status = AudioObjectSetPropertyData(
            deviceID, &address, 0, nil,
            UInt32(MemoryLayout<UInt32>.size), &value
        )
        guard status == noErr else {
            throw .osStatus(status, context: muted ? "muting output" : "unmuting output")
        }
    }

    // MARK: - Private: Listener Registration

    private func registerListener(
        selector: AudioObjectPropertySelector,
        context: ListenerContext
    ) throws(CoreAudioError) {
        var address = Self.globalPropertyAddress(selector: selector)

        let status = AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            nil, // nil queue — callback on CoreAudio's internal queue
            context.listenerBlock
        )

        guard status == noErr else {
            throw .osStatus(status, context: "registering listener for selector \(selector)")
        }
    }

    private func unregisterListener(
        selector: AudioObjectPropertySelector,
        context: ListenerContext
    ) {
        var address = Self.globalPropertyAddress(selector: selector)

        AudioObjectRemovePropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            nil,
            context.listenerBlock
        )
    }

    // MARK: - Private: Helpers

    /// Global-scope property address for system-wide audio properties.
    private static func globalPropertyAddress(
        selector: AudioObjectPropertySelector
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
    }
}

// MARK: - ListenerContext

/// Bridges CoreAudio's C callback into actor isolation.
///
/// CoreAudio's `AudioObjectPropertyListenerBlock` executes on an arbitrary dispatch queue
/// and cannot directly call actor-isolated methods. This class bridges the gap:
/// the block posts to the actor via `Task { await service.handlePropertyChange() }`.
///
/// ## Why `@unchecked Sendable`
/// `isValid` is a single `Bool` written only from the actor (`invalidate()`) and read
/// from the callback. Single-word reads are atomic on ARM64/x86_64. False positives
/// (reading `true` after invalidation) produce one extra no-op `Task` — harmless.
///
/// ## Lifecycle
/// - Created in `startMonitoring()`, stored in `State.monitoring`.
/// - Invalidated in `stopMonitoring()` before unregistering listeners.
/// - `listenerBlock` identity is stable once accessed — required for
///   `AudioObjectRemovePropertyListenerBlock` matching.
private final class ListenerContext: @unchecked Sendable {

    private weak var service: CoreAudioService?
    private var isValid = true

    /// The listener block registered with CoreAudio.
    /// `lazy var` defers creation until after `init` completes, allowing `[weak self]`
    /// capture without the need for a separate `Box` indirection class.
    /// `private(set)` ensures the block identity remains stable for add/remove pairing.
    private(set) lazy var listenerBlock: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
        guard let self, self.isValid, let service = self.service else { return }
        Task { await service.handlePropertyChange() }
    }

    init(service: CoreAudioService) {
        self.service = service
    }

    /// Mark this context as stale. Prevents callbacks from reaching the actor
    /// after `stopMonitoring()` but before CoreAudio fully unregisters the listener.
    func invalidate() {
        isValid = false
        service = nil
    }
}
