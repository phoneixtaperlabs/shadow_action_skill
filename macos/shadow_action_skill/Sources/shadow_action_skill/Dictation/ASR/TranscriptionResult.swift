import Foundation

// MARK: - TranscriptionResult

/// A single transcription result emitted during streaming recognition.
///
/// Results arrive incrementally: partial results have `isFinal == false`
/// and may be revised, while confirmed results have `isFinal == true`.
///
/// Every ASR provider produces this same type regardless of its internal
/// representation. (Predictability — unified return type across providers)
struct TranscriptionResult: Sendable {

    /// The transcribed text for this segment.
    let text: String

    /// Whether this result is finalized or may still change.
    let isFinal: Bool

    /// Overall confidence score (0.0 ... 1.0). Provider-specific semantics.
    let confidence: Float

    /// Time-aligned segments within this result, when available.
    let segments: [TranscriptionSegment]

    /// Timestamp when this result was produced.
    let timestamp: Date

    init(
        text: String,
        isFinal: Bool,
        confidence: Float,
        segments: [TranscriptionSegment] = [],
        timestamp: Date = Date()
    ) {
        self.text = text
        self.isFinal = isFinal
        self.confidence = confidence
        self.segments = segments
        self.timestamp = timestamp
    }
}

// MARK: - Flutter Serialization

extension TranscriptionResult {
    /// Flutter channel payload for the `onTranscription` method call.
    var flutterPayload: [String: Any] {
        [
            "text": text,
            "isFinal": isFinal,
            "confidence": confidence,
            "segments": segments.map { segment in
                [
                    "text": segment.text,
                    "startTime": segment.startTime,
                    "endTime": segment.endTime,
                    "confidence": segment.confidence,
                ] as [String: Any]
            },
        ]
    }
}

// MARK: - TranscriptionSegment

/// A time-aligned segment (word or token) within a transcription result.
struct TranscriptionSegment: Sendable {

    /// The text of this segment.
    let text: String

    /// Start time relative to the beginning of the audio stream (seconds).
    let startTime: TimeInterval

    /// End time relative to the beginning of the audio stream (seconds).
    let endTime: TimeInterval

    /// Confidence score for this segment (0.0 ... 1.0).
    let confidence: Float
}
