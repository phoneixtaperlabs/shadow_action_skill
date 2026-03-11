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
    /// - Parameter provider: Provider identifier (case-insensitive). Currently supported: "whisper", "parakeet".
    /// - Returns: An `ASRService` instance, or `nil` if the provider is unknown.
    static func create(provider: String) -> (any ASRService)? {
        switch provider.lowercased() {
        case "whisper":
            return WhisperService()
        case "parakeet":
            return ParakeetService()
        default:
            return nil
        }
    }
}
