import AppKit
import SwiftUI
import OSLog
import FlutterMacOS

// MARK: - KeyablePanel

/// NSPanel subclass that overrides `canBecomeKey` to return `true`.
/// `NSPanel` with `.nonactivatingPanel` style mask hard-codes `canBecomeKeyWindow`
/// to `false`, which blocks TextField keyboard input. This subclass fixes that
/// while keeping the non-activating behaviour (won't steal focus from other apps).
final class KeyablePanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

// MARK: - ManagedWindowController

/// Window controller with delegate for managing window lifecycle
@MainActor
final class ManagedWindowController: NSWindowController, NSWindowDelegate {

    let identifier: String
    private weak var windowManager: WindowManager?

    init(identifier: String, window: NSWindow, windowManager: WindowManager) {
        self.identifier = identifier
        self.windowManager = windowManager
        super.init(window: window)
        window.delegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        windowManager?.handleWindowClosed(identifier: identifier)
    }

    func windowDidMiniaturize(_ notification: Notification) {
        windowManager?.emitEvent(.minimized(windowId: identifier))
    }

    func windowDidDeminiaturize(_ notification: Notification) {
        windowManager?.emitEvent(.restored(windowId: identifier))
    }

    func windowDidMove(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        windowManager?.emitEvent(.moved(windowId: identifier, frame: window.frame))
    }

    func windowDidResize(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        windowManager?.emitEvent(.resized(windowId: identifier, size: window.frame.size))
    }
}

// MARK: - WindowManager

/// Singleton window manager for creating and managing native SwiftUI windows.
///
/// ## Usage
/// ```swift
/// // Show a window with custom SwiftUI content
/// let config = WindowConfiguration(
///     identifier: "myWindow",
///     size: CGSize(width: 300, height: 200),
///     position: .screenCenter
/// )
/// WindowManager.shared.showWindow(configuration: config) {
///     MySwiftUIView()
/// }
///
/// // Close window
/// WindowManager.shared.closeWindow(identifier: "myWindow")
///
/// // Listen to events
/// WindowManager.shared.onWindowEvent = { event in
///     print("Window event: \(event)")
/// }
/// ```
@MainActor
final class WindowManager {

    // MARK: - Singleton

    static let shared = WindowManager()

    private init() {
        logger.info("WindowManager initialized")
    }

    // MARK: - Properties

    private let logger = Logger(subsystem: "shadow_listening", category: "WindowManager")

    /// Active window controllers by identifier
    private var windowControllers: [String: ManagedWindowController] = [:]

    /// Event handler closure for window events
    var onWindowEvent: ((WindowEvent) -> Void)?

    /// Active DictationViewModel (set by DictationView, cleared on disappear)
    @MainActor weak var dictationViewModel: DictationViewModel?

    // MARK: - Public API

    /// Check if a window with given identifier exists and is visible
    func isWindowVisible(identifier: String) -> Bool {
        guard let controller = windowControllers[identifier],
              let window = controller.window else { return false }
        return window.isVisible
    }

    /// Get all active window identifiers
    var activeWindowIdentifiers: [String] {
        return Array(windowControllers.keys)
    }

    /// identifier로 관리 중인 NSWindow 반환
    func getWindow(identifier: String) -> NSWindow? {
        windowControllers[identifier]?.window
    }

    /// Show a window with SwiftUI content
    /// - Parameters:
    ///   - configuration: Window configuration
    ///   - content: SwiftUI view builder
    @MainActor
    func showWindow<Content: View>(
        configuration: WindowConfiguration,
        @ViewBuilder content: () -> Content
    ) {
        let identifier = configuration.identifier

        // Close existing window with same identifier
        if windowControllers[identifier] != nil {
            closeWindow(identifier: identifier)
        }

        // Create window
        let window = createWindow(configuration: configuration)

        // Create hosting view with content
        let hostingView = FirstClickHostingView(rootView: content())
        window.contentView = hostingView

        // Create window controller
        let controller = ManagedWindowController(
            identifier: identifier,
            window: window,
            windowManager: self
        )

        // Store reference
        windowControllers[identifier] = controller

        // Determine actual size — either from config or from SwiftUI content
        var resolvedConfig = configuration
        if configuration.sizingMode == .fitContent {
            hostingView.layoutSubtreeIfNeeded()
            resolvedConfig.size = hostingView.fittingSize
        }

        // Calculate and set position
        let frame = calculateFrame(configuration: resolvedConfig)
        window.setFrame(frame, display: true)

        // Show window
        controller.showWindow(nil)
        if configuration.style.canBecomeKey {
            window.makeKeyAndOrderFront(nil)
        } else {
            window.orderFront(nil)
        }

        logger.info("[WindowManager] Window '\(identifier)' shown at \(NSStringFromRect(frame))")

        // Emit event
        emitEvent(.opened(windowId: identifier))
    }

    /// Close a window by identifier
    @MainActor
    func closeWindow(identifier: String) {
        guard let controller = windowControllers[identifier] else {
            logger.warning("[WindowManager] Window '\(identifier)' not found for close")
            return
        }

        controller.window?.close()

        logger.info("[WindowManager] Window '\(identifier)' closed")
    }

    /// Close all managed windows
    @MainActor
    func closeAllWindows() {
        let identifiers = Array(windowControllers.keys)
        for identifier in identifiers {
            closeWindow(identifier: identifier)
        }
        logger.info("[WindowManager] All windows closed")
    }

    /// Update position of an existing window
    @MainActor
    func updatePosition(identifier: String, position: WindowPosition) {
        guard let controller = windowControllers[identifier],
              let window = controller.window else {
            logger.warning("[WindowManager] Window '\(identifier)' not found for position update")
            return
        }

        let origin = calculateOrigin(for: position, size: window.frame.size)
        let newFrame = CGRect(origin: origin, size: window.frame.size)

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrame(newFrame, display: true)
        }

        logger.info("[WindowManager] Window '\(identifier)' position updated to \(NSStringFromPoint(newFrame.origin))")
    }

    /// Update size of an existing window
    @MainActor
    func updateSize(identifier: String, size: CGSize) {
        guard let controller = windowControllers[identifier],
              let window = controller.window else {
            logger.warning("[WindowManager] Window '\(identifier)' not found for size update")
            return
        }

        let newFrame = CGRect(origin: window.frame.origin, size: size)
        window.setFrame(newFrame, display: true, animate: true)

        logger.info("[WindowManager] Window '\(identifier)' size updated to \(NSStringFromSize(size))")
    }

    // MARK: - Internal (Called by WindowController)

    @MainActor
    func handleWindowClosed(identifier: String) {
        windowControllers.removeValue(forKey: identifier)
        if identifier == "listening" {
            dictationViewModel = nil
        }
        emitEvent(.closed(windowId: identifier))
        logger.info("[WindowManager] Window '\(identifier)' closed via delegate")
    }

    func emitEvent(_ event: WindowEvent) {
        // Call local handler
        onWindowEvent?(event)

        // Send to Flutter via FlutterBridge
        FlutterBridge.shared.invokeWindowEvent(event.toDictionary())
    }

    // MARK: - Private Methods

    private func createWindow(configuration: WindowConfiguration) -> NSWindow {
        let style = configuration.style

        // NSPanel path — non-activating, preserves focus on the active app
        if configuration.usePanel {
            let panelType: NSPanel.Type = style.canBecomeKey ? KeyablePanel.self : NSPanel.self
            let panel = panelType.init(
                contentRect: NSRect(origin: .zero, size: configuration.size),
                styleMask: [.nonactivatingPanel, .borderless, .hudWindow],
                backing: .buffered,
                defer: false,
                screen: NSScreen.main
            )
            panel.identifier = NSUserInterfaceItemIdentifier(configuration.identifier)
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = style.hasShadow
            panel.isMovableByWindowBackground = style.isMovableByBackground
            panel.ignoresMouseEvents = style.ignoresMouseEvents
            panel.isReleasedWhenClosed = false
            panel.becomesKeyOnlyIfNeeded = !style.canBecomeKey
            panel.acceptsMouseMovedEvents = true
            panel.sharingType = style.sharingType
            panel.titlebarAppearsTransparent = true
            panel.titleVisibility = .hidden
            panel.contentView?.wantsLayer = true
            panel.contentView?.layer?.cornerRadius = 0
            return panel
        }

        // Determine style mask
        var styleMask: NSWindow.StyleMask = [.titled, .closable, .miniaturizable, .fullSizeContentView]
        if !style.showsTitlebar {
            styleMask.insert(.borderless)
        }

        // Create window
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: configuration.size),
            styleMask: styleMask,
            backing: .buffered,
            defer: false,
            screen: NSScreen.main
        )

        window.identifier = NSUserInterfaceItemIdentifier(configuration.identifier)

        // Apply style
        window.level = style.level
        window.isOpaque = !style.isTransparent
        window.backgroundColor = style.isTransparent ? .clear : .windowBackgroundColor
        window.hasShadow = style.hasShadow
        window.isMovableByWindowBackground = style.isMovableByBackground
        window.ignoresMouseEvents = style.ignoresMouseEvents
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.sharingType = style.sharingType
        window.isReleasedWhenClosed = false

        // Titlebar configuration
        if !style.showsTitlebar {
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.standardWindowButton(.closeButton)?.isHidden = true
            window.standardWindowButton(.miniaturizeButton)?.isHidden = true
            window.standardWindowButton(.zoomButton)?.isHidden = true
        }

        // Size constraints
        if let minSize = configuration.minSize {
            window.minSize = minSize
        }
        if let maxSize = configuration.maxSize {
            window.maxSize = maxSize
        }

        // Content view setup
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.cornerRadius = 0

        return window
    }

    private func calculateFrame(configuration: WindowConfiguration) -> CGRect {
        let size = configuration.size
        let origin = calculateOrigin(for: configuration.position, size: size)
        return CGRect(origin: origin, size: size)
    }

    private func calculateOrigin(for position: WindowPosition, size: CGSize) -> CGPoint {
        guard let screen = NSScreen.main else {
            return .zero
        }

        let screenFrame = screen.visibleFrame

        switch position {
        case .screenCenter:
            return CGPoint(
                x: screenFrame.midX - size.width / 2,
                y: screenFrame.midY - size.height / 2
            )

        case .screen(let anchor, let offset):
            let basePoint = screenAnchorPoint(anchor, in: screenFrame, windowSize: size)
            return CGPoint(x: basePoint.x + offset.x, y: basePoint.y + offset.y)

        case .flutterWindow(let anchor, let offset):
            guard let flutterFrame = findFlutterWindowFrame() else {
                logger.warning("[WindowManager] Flutter window not found, falling back to screen center")
                return calculateOrigin(for: .screenCenter, size: size)
            }
            let basePoint = flutterWindowAnchorPoint(anchor, in: flutterFrame, windowSize: size)
            return CGPoint(x: basePoint.x + offset.x, y: basePoint.y + offset.y)

        case .absolute(let point):
            return point
        }
    }

    private func screenAnchorPoint(_ anchor: ScreenAnchor, in frame: CGRect, windowSize: CGSize) -> CGPoint {
        switch anchor {
        case .topLeft:
            return CGPoint(x: frame.minX, y: frame.maxY - windowSize.height)
        case .topCenter:
            return CGPoint(x: frame.midX - windowSize.width / 2, y: frame.maxY - windowSize.height)
        case .topRight:
            return CGPoint(x: frame.maxX - windowSize.width, y: frame.maxY - windowSize.height)
        case .centerLeft:
            return CGPoint(x: frame.minX, y: frame.midY - windowSize.height / 2)
        case .center:
            return CGPoint(x: frame.midX - windowSize.width / 2, y: frame.midY - windowSize.height / 2)
        case .centerRight:
            return CGPoint(x: frame.maxX - windowSize.width, y: frame.midY - windowSize.height / 2)
        case .bottomLeft:
            return CGPoint(x: frame.minX, y: frame.minY)
        case .bottomCenter:
            return CGPoint(x: frame.midX - windowSize.width / 2, y: frame.minY)
        case .bottomRight:
            return CGPoint(x: frame.maxX - windowSize.width, y: frame.minY)
        }
    }

    private func flutterWindowAnchorPoint(_ anchor: FlutterWindowAnchor, in frame: CGRect, windowSize: CGSize) -> CGPoint {
        switch anchor {
        case .topLeft:
            return CGPoint(x: frame.minX, y: frame.maxY)
        case .topRight:
            return CGPoint(x: frame.maxX, y: frame.maxY)
        case .bottomLeft:
            return CGPoint(x: frame.minX, y: frame.minY - windowSize.height)
        case .bottomRight:
            return CGPoint(x: frame.maxX, y: frame.minY - windowSize.height)
        case .leftCenter:
            return CGPoint(x: frame.minX - windowSize.width, y: frame.midY - windowSize.height / 2)
        case .rightCenter:
            return CGPoint(x: frame.maxX, y: frame.midY - windowSize.height / 2)
        }
    }

    private func findFlutterWindowFrame() -> CGRect? {
        for window in NSApplication.shared.windows {
            if window.className.contains("MainFlutterWindow") ||
               window.contentViewController?.className.contains("FlutterViewController") == true {
                return window.frame
            }
        }
        return nil
    }
}

// MARK: - Window Position

/// Defines how a window should be positioned on screen
enum WindowPosition: Equatable {
    /// Center of the main screen
    case screenCenter

    /// Position relative to a screen edge/corner
    case screen(ScreenAnchor, offset: CGPoint)

    /// Position relative to the main Flutter window
    case flutterWindow(FlutterWindowAnchor, offset: CGPoint)

    /// Absolute position (origin = bottom-left corner in macOS coordinates)
    case absolute(CGPoint)
}

/// Screen anchor points for positioning
enum ScreenAnchor: String, Equatable {
    case topLeft
    case topCenter
    case topRight
    case centerLeft
    case center
    case centerRight
    case bottomLeft
    case bottomCenter
    case bottomRight
}

/// Anchor points relative to Flutter window
enum FlutterWindowAnchor: String, Equatable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
    case leftCenter
    case rightCenter
}

// MARK: - Window Style

/// Window appearance configuration
struct WindowStyle: Equatable {
    /// Window floats above other windows
    var isFloating: Bool

    /// Background is transparent (for custom shapes)
    var isTransparent: Bool

    /// Show titlebar
    var showsTitlebar: Bool

    /// Window level (floating, normal, etc.)
    var level: NSWindow.Level

    /// Can become key window (receive keyboard input)
    var canBecomeKey: Bool

    /// Window is movable by dragging background
    var isMovableByBackground: Bool

    /// Show window shadow
    var hasShadow: Bool

    /// Window ignores all mouse events (clicks pass through to windows below)
    var ignoresMouseEvents: Bool

    /// Whether the window is excluded from screenshots and screen recordings.
    /// `.none` excludes the window from capture.
    var sharingType: NSWindow.SharingType

    // MARK: - Presets

    /// Floating transparent panel (default for overlay windows)
    static let floatingPanel = WindowStyle(
        isFloating: true,
        isTransparent: true,
        showsTitlebar: false,
        level: .floating,
        canBecomeKey: true,
        isMovableByBackground: true,
        hasShadow: false,
        ignoresMouseEvents: false,
        sharingType: .none
    )

    /// Standard window with titlebar
    static let standard = WindowStyle(
        isFloating: false,
        isTransparent: false,
        showsTitlebar: true,
        level: .normal,
        canBecomeKey: true,
        isMovableByBackground: false,
        hasShadow: true,
        ignoresMouseEvents: false,
        sharingType: .none
    )

    /// Click-through overlay — fully transparent to mouse events
    static let overlay = WindowStyle(
        isFloating: true,
        isTransparent: true,
        showsTitlebar: false,
        level: .floating,
        canBecomeKey: false,
        isMovableByBackground: false,
        hasShadow: false,
        ignoresMouseEvents: true,
        sharingType: .none
    )

    /// Non-activating floating panel — does NOT steal focus from the active app.
    /// Requires `usePanel = true` on `WindowConfiguration` to create an `NSPanel`.
    static let nonActivatingPanel = WindowStyle(
        isFloating: true,
        isTransparent: true,
        showsTitlebar: false,
        level: .floating,
        canBecomeKey: false,
        isMovableByBackground: false,
        hasShadow: false,
        ignoresMouseEvents: false,
        sharingType: .readOnly
    )

    /// Non-activating panel that can become key — accepts keyboard input (e.g. TextField)
    /// without activating the owning app. Requires `usePanel = true`.
    static let nonActivatingKeyPanel = WindowStyle(
        isFloating: true,
        isTransparent: true,
        showsTitlebar: false,
        level: .floating,
        canBecomeKey: true,
        isMovableByBackground: false,
        hasShadow: false,
        ignoresMouseEvents: false,
        sharingType: .readOnly
    )
}

// MARK: - Window Sizing Mode

/// How the window determines its size.
enum WindowSizingMode {
    /// Window uses the exact `size` from configuration. (Default)
    case fixed
    /// Window sizes to fit the SwiftUI content's intrinsic size.
    /// Uses `NSHostingView.fittingSize` after layout.
    case fitContent
}

// MARK: - Window Configuration

/// Complete configuration for creating a managed window
struct WindowConfiguration {
    /// Unique identifier for this window
    let identifier: String

    /// Window size
    var size: CGSize

    /// Position configuration
    var position: WindowPosition

    /// Visual style
    var style: WindowStyle

    /// Minimum size (optional)
    var minSize: CGSize?

    /// Maximum size (optional)
    var maxSize: CGSize?

    /// How the window determines its size.
    /// `.fixed` uses `size` directly. `.fitContent` queries the SwiftUI content's intrinsic size.
    var sizingMode: WindowSizingMode

    /// When `true`, `WindowManager` creates an `NSPanel` instead of `NSWindow`.
    /// Required for non-activating overlays that must not steal focus.
    var usePanel: Bool

    // MARK: - Default Configuration

    init(
        identifier: String,
        size: CGSize,
        position: WindowPosition = .screenCenter,
        style: WindowStyle = .floatingPanel,
        minSize: CGSize? = nil,
        maxSize: CGSize? = nil,
        sizingMode: WindowSizingMode = .fixed,
        usePanel: Bool = false
    ) {
        self.identifier = identifier
        self.size = size
        self.position = position
        self.style = style
        self.minSize = minSize
        self.maxSize = maxSize
        self.sizingMode = sizingMode
        self.usePanel = usePanel
    }
}

// MARK: - Window Events

/// Events emitted by managed windows
enum WindowEvent: Equatable {
    case opened(windowId: String)
    case closed(windowId: String)
    case minimized(windowId: String)
    case restored(windowId: String)
    case moved(windowId: String, frame: CGRect)
    case resized(windowId: String, size: CGSize)

    /// Convert to dictionary for Flutter communication
    func toDictionary() -> [String: Any] {
        switch self {
        case .opened(let windowId):
            return ["event": "opened", "windowId": windowId]
        case .closed(let windowId):
            return ["event": "closed", "windowId": windowId]
        case .minimized(let windowId):
            return ["event": "minimized", "windowId": windowId]
        case .restored(let windowId):
            return ["event": "restored", "windowId": windowId]
        case .moved(let windowId, let frame):
            return [
                "event": "moved",
                "windowId": windowId,
                "frame": ["x": frame.origin.x, "y": frame.origin.y, "width": frame.width, "height": frame.height]
            ]
        case .resized(let windowId, let size):
            return [
                "event": "resized",
                "windowId": windowId,
                "size": ["width": size.width, "height": size.height]
            ]
        }
    }
}
