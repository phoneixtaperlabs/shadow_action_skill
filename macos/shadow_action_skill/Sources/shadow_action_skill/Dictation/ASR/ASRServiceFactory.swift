// MARK: - WhisperModel

/// Known Whisper GGML model filenames. Mirrors the Dart `WhisperModel` enum.
///
/// Validated at the platform-channel boundary so invalid filenames fail fast
/// in `ASRServiceFactory.create`, not deep in `WhisperService.prepare`. (Predictability)
enum WhisperModel: String {
    case smallQ5_1        = "ggml-small-q5_1.bin"
    case largeV3TurboQ5_0 = "ggml-large-v3-turbo-q5_0.bin"
}

// MARK: - ASRServiceFactory

/// Creates ASR service instances by provider name.
///
/// Adding a new provider requires only:
/// 1. Creating a new file implementing `ASRService` (e.g., `ParakeetService.swift`)
/// 2. Adding a case to this factory's `create` switch
///
/// Consumers never reference concrete types directly. (Coupling)
enum ASRServiceFactory {

    /// Known ASR provider identifiers.
    static let availableProviders = ["whisper", "parakeet"]

    /// Create an ASR service for the given provider name.
    ///
    /// - Parameters:
    ///   - provider: Provider identifier (case-insensitive). Currently supported: "whisper", "parakeet".
    ///   - whisperModelName: Optional model filename override for the Whisper provider.
    ///     Must match a known `WhisperModel` raw value; unknown values return `nil`.
    ///     Nil uses `WhisperServiceConfig.default.modelName`.
    /// - Returns: An `ASRService` instance, or `nil` if the provider or model name is unknown.
    static func create(provider: String, whisperModelName: String? = nil) -> (any ASRService)? {
        switch provider.lowercased() {
        case "whisper":
            var config = WhisperServiceConfig.default
            if let name = whisperModelName {
                guard let model = WhisperModel(rawValue: name) else { return nil }
                config.modelName = model.rawValue
            }
            return WhisperService(config: config)
        case "parakeet":
            return ParakeetService()
        default:
            return nil
        }
    }
}
