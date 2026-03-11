import AppKit
import OSLog
import ScreenCaptureKit

// MARK: - ScreenshotService

/// Captures a full-screen screenshot of the main display using ScreenCaptureKit
/// and writes it as a JPEG file to the app's support directory.
///
/// ## Concurrency Model
/// Stateless — `enum` with static methods. No mutable state means no isolation needed.
/// ScreenCaptureKit async APIs suspend and resume correctly on any executor.
///
/// ## Design
/// `captureScreenshot` orchestrates three focused helpers — each owns one
/// abstraction level and one reason to change. (Readability, Coupling)
enum ScreenshotService {

    // MARK: - Result Type

    /// Structured result from a screenshot capture.
    struct ScreenshotResult {
        let filePath: String
        let timestamp: Int

        /// Converts to a dictionary for the Flutter method channel.
        func toMap() -> [String: Any] {
            [
                "filePath": filePath,
                "timestamp": timestamp,
            ]
        }
    }

    // MARK: - Private Properties

    private static let logger = Logger(subsystem: "shadow_action_skill", category: "Screenshot")

    /// Directory for screenshot output files.
    private static let outputDirectory: URL = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/com.taperlabs.shadow", isDirectory: true)
    }()

    // MARK: - Public API

    /// Captures the main display and writes the screenshot as a JPEG file.
    ///
    /// - Parameters:
    ///   - quality: JPEG compression quality from 0.0 (max compression) to 1.0 (best quality).
    ///     Defaults to `0.8`.
    ///   - fileName: Optional custom file name (e.g. `"capture.jpg"`).
    ///     Defaults to `screenshot_<timestamp>.jpg`.
    /// - Returns: A `ScreenshotResult` with the file path and capture timestamp.
    /// - Throws: `ScreenshotError` if any step fails.
    static func captureScreenshot(
        quality: Double = 0.8,
        fileName: String? = nil
    ) async throws(ScreenshotError) -> ScreenshotResult {
        let cgImage = try await captureDisplay()
        let jpegData = try encodeJPEG(cgImage, quality: quality)
        return try persistToFile(jpegData, fileName: fileName)
    }

    // MARK: - Private Helpers

    /// Captures the main display as a `CGImage` via ScreenCaptureKit.
    ///
    /// Handles permission check, display discovery, filter/config setup, and capture.
    private static func captureDisplay() async throws(ScreenshotError) -> CGImage {
        let content: SCShareableContent
        do {
            content = try await SCShareableContent.current
        } catch {
            logger.error("[Screenshot] Failed to get shareable content: \(error.localizedDescription)")
            throw .screenRecordingPermissionDenied
        }

        guard let display = content.displays.first else {
            logger.error("[Screenshot] No displays found")
            throw .noDisplayFound
        }

        logger.info("[Screenshot] Capturing display: \(display.width)x\(display.height)")

        let filter = SCContentFilter(
            display: display,
            excludingApplications: [],
            exceptingWindows: []
        )

        let configuration = SCStreamConfiguration()
        configuration.width = display.width
        configuration.height = display.height
        configuration.pixelFormat = kCVPixelFormatType_32BGRA
        configuration.showsCursor = false

        do {
            return try await SCScreenshotManager.captureImage(
                contentFilter: filter,
                configuration: configuration
            )
        } catch {
            logger.error("[Screenshot] Capture failed: \(error.localizedDescription)")
            throw .captureFailed(underlying: error)
        }
    }

    /// Encodes a `CGImage` as JPEG data at the given quality.
    private static func encodeJPEG(_ image: CGImage, quality: Double) throws(ScreenshotError) -> Data {
        let bitmapRep = NSBitmapImageRep(cgImage: image)
        let clampedQuality = min(max(quality, 0.0), 1.0)

        guard let jpegData = bitmapRep.representation(
            using: .jpeg,
            properties: [.compressionFactor: clampedQuality]
        ) else {
            logger.error("[Screenshot] JPEG encoding failed")
            throw .jpegEncodingFailed
        }

        return jpegData
    }

    /// Writes JPEG data to disk and returns the result.
    ///
    /// - Parameters:
    ///   - data: The JPEG data to persist.
    ///   - fileName: Custom file name, or `nil` to use `screenshot_<timestamp>.jpg`.
    private static func persistToFile(
        _ data: Data,
        fileName: String?
    ) throws(ScreenshotError) -> ScreenshotResult {
        do {
            try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        } catch {
            logger.error("[Screenshot] Failed to create output directory: \(error.localizedDescription)")
            throw .fileWriteFailed(underlying: error)
        }

        let timestamp = Int(Date().timeIntervalSince1970)
        let resolvedName = fileName ?? "screenshot_\(timestamp).jpg"
        let fileURL = outputDirectory.appendingPathComponent(resolvedName)

        do {
            try data.write(to: fileURL, options: .atomic)
        } catch {
            logger.error("[Screenshot] File write failed: \(error.localizedDescription)")
            throw .fileWriteFailed(underlying: error)
        }

        logger.info("[Screenshot] Saved \(data.count) bytes to \(fileURL.path)")
        return ScreenshotResult(filePath: fileURL.path, timestamp: timestamp)
    }
}
