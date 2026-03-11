import SwiftUI

// MARK: - AudioDeviceSelectView

/// Floating picker for selecting the preferred audio input device.
///
/// Two sections:
/// - Top: scrollable list of physical input devices
/// - Bottom: current device indicator with microphone icon
///
/// Follows `DeviceNotificationView` pattern: `RoundedRectangle` cornerRadius 12,
/// `backgroundHard` fill, `borderHard` stroke. (Coupling)
struct AudioDeviceSelectView: View {

    @State private var viewModel = AudioDeviceSelectViewModel()

    static let windowIdentifier = "audioDeviceSelect"

    // MARK: - Window Lifecycle

    /// Present the device picker as a floating panel. (Cohesion — view owns its presentation config)
    static func showWindow() {
        let config = WindowConfiguration(
            identifier: windowIdentifier,
            size: .zero,
            position: .screenCenter,
            style: .floatingPanel,
            sizingMode: .fitContent,
            usePanel: true
        )
        WindowManager.shared.showWindow(configuration: config) {
            AudioDeviceSelectView()
        }
    }

    static func dismissWindow() {
        WindowManager.shared.closeWindow(identifier: windowIdentifier)
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                deviceList
//                divider
//                currentDeviceIndicator
            }
            closeButton
        }
        .frame(width: 280)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.backgroundHard)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.borderHard, lineWidth: 1)
        }
        .clipShape(.rect(cornerRadius: 12))
        .task {
            await viewModel.startMonitoring()
        }
        .onDisappear {
            Task { await viewModel.stopMonitoring() }
        }
    }

    // MARK: - Close Button

    private var closeButton: some View {
        Button(action: dismiss) {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.text4)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(8)
    }

    private func dismiss() {
        FlutterBridge.shared.send("onAudioDeviceSelectDismissed")
    }

    // MARK: - Device List (Top Section)

    private var totalRowCount: Int {
        viewModel.inputDevices.count
    }

    private static let rowHeight: CGFloat = 32
    private static let maxListHeight: CGFloat = 300

    private var deviceList: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(viewModel.inputDevices) { device in
                    DeviceRow(
                        name: device.name,
                        isSelected: viewModel.isDeviceSelected(device),
                        action: { viewModel.selectDevice(device) }
                    )
                    .frame(height: Self.rowHeight)
                }
            }
            .padding(.vertical, 6)
        }
        .frame(height: min(CGFloat(totalRowCount) * Self.rowHeight + 8, Self.maxListHeight))
    }

    // MARK: - Divider

    private var divider: some View {
        Rectangle()
            .fill(Color.borderHard)
            .frame(height: 1)
    }

    // MARK: - Current Device Indicator (Bottom Section)

    private var currentDeviceIndicator: some View {
        CurrentDeviceIndicator(deviceName: viewModel.activeDeviceDisplayName)
    }
}

// MARK: - DeviceRow

/// A single physical device row in the list.
/// Extracted subview for optimal SwiftUI diffing. (Readability)
private struct DeviceRow: View {

    let name: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(name)
                    .font(.system(size: 13))
                    .foregroundStyle(isSelected ? Color.brandSecondary : Color.text1)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - CurrentDeviceIndicator

/// Bottom section showing the currently active device with a microphone icon.
/// Extracted subview for optimal SwiftUI diffing. (Readability)
private struct CurrentDeviceIndicator: View {

    let deviceName: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "mic.fill")
                .font(.system(size: 14))
                .foregroundStyle(Color.brandSecondary)

            Text(deviceName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.text0)
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Preview

#if DEBUG
struct AudioDeviceSelectView_Previews: PreviewProvider {
    static var previews: some View {
        AudioDeviceSelectView()
            .background(Color.black)
    }
}
#endif
