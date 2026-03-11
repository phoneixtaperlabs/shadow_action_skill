/// Virtual key codes for CGEvent keyboard simulation.
///
/// Carbon's `Events.h` defines these as `kVK_*` constants, but they are
/// not available in Swift Package Manager targets (no Carbon module map).
/// Defined here as a namespace to avoid polluting the global scope. (Readability)
enum KeyCode {
    static let a: UInt16 = 0x00       // kVK_ANSI_A
    static let c: UInt16 = 0x08       // kVK_ANSI_C
    static let v: UInt16 = 0x09       // kVK_ANSI_V
    static let command: UInt16 = 0x37  // kVK_Command
}
