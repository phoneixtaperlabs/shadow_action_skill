import AppKit
import OSLog

// MARK: - AccessibilityService

/// Manages macOS Accessibility operations: permission checks, keystroke simulation,
/// and clipboard management.
///
/// ## Concurrency Model
/// `@MainActor` because the majority of methods touch `NSPasteboard` (AppKit, safest
/// on main thread). Permission and keystroke methods are `nonisolated` since they call
/// thread-safe C functions / HID system APIs.
///
/// No mutable state — actor isolation would add `await` overhead with no safety benefit.
/// `Task.sleep` in `copy()` / `paste()` **yields** the main actor (does not block it).
@MainActor
final class AccessibilityService {

    // MARK: - Singleton

    static let shared = AccessibilityService()
    private init() {}

    // MARK: - Private Properties

    private let logger = Logger(subsystem: "shadow_action_skill", category: "Accessibility")

    /// Delay after simulating a keystroke before reading clipboard.
    private static let keystrokeClipboardDelayNs: UInt64 = 100_000_000  // 100ms

    /// Maximum number of poll attempts after Cmd+C to detect clipboard change.
    private static let copyPollMaxAttempts = 10

    /// Delay between clipboard poll attempts.
    private static let copyPollIntervalNs: UInt64 = 50_000_000  // 50ms

    /// Delay between key-down and key-up events for realistic keystroke timing.
    private static let keyUpDelayMicroseconds: useconds_t = 50_000  // 50ms

    // MARK: - Permission

    /// Check if the app has Accessibility permission.
    /// Returns `true` if trusted, `false` otherwise. Does NOT prompt the user.
    nonisolated func checkPermission() -> Bool {
        AXIsProcessTrusted()
    }

    /// Opens System Settings to the Accessibility pane and checks trust status.
    /// Returns `true` if already trusted (user previously granted).
    /// If not trusted, macOS shows the System Settings prompt.
    nonisolated func requestPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - Keystroke Simulation

    /// Simulate a key press + release with optional modifier flags.
    ///
    /// Checks `AXIsProcessTrusted()` before posting — throws `.accessibilityPermissionDenied`
    /// if not trusted. Without this guard, CGEvent silently drops events. (Defense in depth)
    ///
    /// - Parameters:
    ///   - keyCode: Virtual key code (see `KeyCode`).
    ///   - flags: Modifier flags (e.g., `.maskCommand`).
    nonisolated func simulateKeystroke(
        keyCode: UInt16,
        flags: CGEventFlags = []
    ) throws(AccessibilityError) {
        guard AXIsProcessTrusted() else {
            throw .accessibilityPermissionDenied
        }

        guard let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false)
        else {
            throw .keystrokeSimulationFailed(keyCode: keyCode)
        }
        keyDown.flags = flags
        keyUp.flags = flags

        // Post directly to the frontmost app's PID to bypass global event
        // tap filtering that drops repeated synthetic keystrokes.
        let post: (CGEvent) -> Void
        if let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier {
            post = { $0.postToPid(pid) }
        } else {
            post = { $0.post(tap: .cghidEventTap) }
        }

        post(keyDown)
        usleep(Self.keyUpDelayMicroseconds)
        post(keyUp)
    }

    // MARK: - AX Selected Text

    /// Reads the selected text from the focused UI element via the Accessibility API.
    /// Returns `nil` if no element is focused, no text is selected, or the app
    /// doesn't support `kAXSelectedTextAttribute`.
    nonisolated private func getSelectedText() -> String? {
        let systemWide = AXUIElementCreateSystemWide()

        var focusedValue: AnyObject?
        let focusedResult = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        )
        guard focusedResult == .success, let focusedElement = focusedValue else {
            return nil
        }

        var selectedValue: AnyObject?
        let selectedResult = AXUIElementCopyAttributeValue(
            focusedElement as! AXUIElement,
            kAXSelectedTextAttribute as CFString,
            &selectedValue
        )
        guard selectedResult == .success, let text = selectedValue as? String else {
            return nil
        }

        return text.isEmpty ? nil : text
    }

    // MARK: - Clipboard

    /// Read the current string content from the system clipboard.
    /// Returns `nil` if there is no string content (not an error for direct reads).
    func getClipboardContent() -> String? {
        NSPasteboard.general.string(forType: .string)
    }

    /// Write a string to the system clipboard.
    func setClipboardContent(_ text: String) throws(AccessibilityError) {
        NSPasteboard.general.clearContents()
        let success = NSPasteboard.general.setString(text, forType: .string)
        guard success else {
            throw .clipboardWriteFailed
        }
    }

    // MARK: - Clipboard Preservation

    /// Snapshot of all pasteboard items and their typed data.
    private typealias PasteboardSnapshot = [[NSPasteboard.PasteboardType: Data]]

    /// Captures every item and type currently on the pasteboard.
    private func savePasteboard() -> PasteboardSnapshot {
        NSPasteboard.general.pasteboardItems?.map { item in
            var data: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let d = item.data(forType: type) {
                    data[type] = d
                }
            }
            return data
        } ?? []
    }

    /// Restores a previously saved pasteboard snapshot.
    private func restorePasteboard(_ snapshot: PasteboardSnapshot) {
        guard !snapshot.isEmpty else { return }
        NSPasteboard.general.clearContents()
        for itemData in snapshot {
            let item = NSPasteboardItem()
            for (type, data) in itemData {
                item.setData(data, forType: type)
            }
            NSPasteboard.general.writeObjects([item])
        }
    }

    // MARK: - Compound Operations

    /// Copy: reads selected text from the focused element via the Accessibility API.
    ///
    /// **Primary strategy:** `kAXSelectedTextAttribute` — instant, no clipboard side effects.
    /// **Fallback:** Simulates Cmd+C and polls `NSPasteboard.general.changeCount` for a
    /// clipboard write (handles apps that don't expose the AX attribute).
    ///
    /// - Parameter selectAll: If `true`, simulates Cmd+A before reading.
    /// - Returns: The selected/copied text.
    func copy(selectAll: Bool = false) async throws(AccessibilityError) -> String {
        if selectAll {
            try simulateKeystroke(keyCode: KeyCode.a, flags: .maskCommand)
            try? await Task.sleep(nanoseconds: Self.keystrokeClipboardDelayNs)
        }

        // Primary: read selected text directly via AX API
        if let text = getSelectedText() {
            logger.info("[Accessibility] Copy via AX selected text")
            return text
        }

        // Fallback: simulate Cmd+C and poll changeCount.
        // Snapshot the clipboard so we can restore it after reading the copied text.
        logger.info("[Accessibility] AX selected text unavailable, falling back to Cmd+C")
        let snapshot = savePasteboard()
        defer { restorePasteboard(snapshot) }

        let changeCountBefore = NSPasteboard.general.changeCount
        try simulateKeystroke(keyCode: KeyCode.c, flags: .maskCommand)

        for _ in 0..<Self.copyPollMaxAttempts {
            try? await Task.sleep(nanoseconds: Self.copyPollIntervalNs)
            if NSPasteboard.general.changeCount != changeCountBefore,
               let content = getClipboardContent() {
                logger.info("[Accessibility] Copy via Cmd+C fallback succeeded")
                return content
            }
        }

        throw .copyTimedOut
    }

    /// Paste: write text to clipboard, simulate Cmd+V, then restore the original clipboard.
    ///
    /// Preserves the user's clipboard content (text, images, files, rich text) by
    /// snapshotting all pasteboard items before the operation and restoring after.
    ///
    /// - Parameter text: The text to paste into the focused application.
    func paste(_ text: String) async throws(AccessibilityError) {
        let snapshot = savePasteboard()
        defer { restorePasteboard(snapshot) }

        try setClipboardContent(text)
        try? await Task.sleep(nanoseconds: Self.keystrokeClipboardDelayNs)
        try simulateKeystroke(keyCode: KeyCode.v, flags: .maskCommand)

        // Allow the target app to read the clipboard before restoring
        try? await Task.sleep(nanoseconds: Self.keystrokeClipboardDelayNs)

        logger.info("[Accessibility] Paste simulated, clipboard restored")
    }
}
