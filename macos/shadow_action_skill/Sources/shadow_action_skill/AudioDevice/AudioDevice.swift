import CoreAudio
import Foundation

// MARK: - AudioDevice

/// A single audio input device reported by CoreAudio.
///
/// Value type containing only `Sendable`-safe primitives (`UInt32`, `String`, `Int`, `Bool`).
/// Safe to pass across actor boundaries. (Coupling — narrow data, no framework types)
struct AudioDevice: Sendable, Identifiable, Equatable, Hashable {

    /// CoreAudio's `AudioDeviceID` (`UInt32` typedef). Volatile — may change across reboots.
    let id: AudioDeviceID

    /// Human-readable device name (e.g., "MacBook Pro Microphone").
    let name: String

    /// Persistent device UID string. Stable across reboots, unlike `id`.
    /// Use this for saving user preferences.
    let uid: String

    /// Number of input channels. Zero means the device has no input capability.
    let inputChannelCount: Int

    /// Whether this is a virtual or aggregate device (typically filtered out for UI).
    let isVirtual: Bool
}

// MARK: - DeviceListSnapshot

/// Immutable snapshot of the current audio device state.
///
/// Bundling the device list with the current default into a single value
/// means consumers get a consistent, atomic view per emission.
/// Avoids race conditions from separate "devices changed" + "default changed" events. (Predictability)
struct DeviceListSnapshot: Sendable, Equatable {

    /// All physical input devices currently connected (virtual/aggregate filtered out).
    let inputDevices: [AudioDevice]

    /// The current system default input device, or `nil` if none is available.
    let defaultInputDevice: AudioDevice?

    /// Timestamp when this snapshot was captured.
    let timestamp: Date
}
