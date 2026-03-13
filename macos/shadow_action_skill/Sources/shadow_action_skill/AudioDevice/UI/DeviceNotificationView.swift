import SwiftUI

// MARK: - DeviceNotificationView

/// Floating tooltip that shows "Using **{DeviceName}**" when dictation starts.
///
/// Auto-dismisses after 2.5 seconds with a fade-out + upward slide animation,
/// then closes its own window. Self-contained lifecycle — the plugin layer
/// does not need a dismiss timer. (Coupling)
struct DeviceNotificationView: View {

    @State private var viewModel: DeviceNotificationViewModel

    private static let windowIdentifier = "deviceNotification"

    init(deviceName: String) {
        _viewModel = State(initialValue: DeviceNotificationViewModel(deviceName: deviceName))
    }

    var body: some View {
        notificationContent
            .opacity(viewModel.isVisible ? 1 : 0)
            .offset(y: viewModel.isVisible ? 0 : -8)
            .animation(.easeInOut(duration: 0.3), value: viewModel.isVisible)
            .task {
                try? await Task.sleep(for: .seconds(5.0))
                viewModel.dismiss()
                // Allow fade-out animation to complete before closing the window.
                try? await Task.sleep(for: .seconds(0.35))
                WindowManager.shared.closeWindow(identifier: Self.windowIdentifier)
            }
    }

    // MARK: - Content

    private var notificationContent: some View {
        (
            Text("Using ")
                .foregroundStyle(Color.text2)
            + Text(viewModel.deviceName)
                .bold()
                .foregroundStyle(Color.text0)
        )
        .font(.system(size: 13))
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.backgroundHard)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.borderSoft, lineWidth: 1)
        }
    }
}

// MARK: - Preview

#if DEBUG
struct DeviceNotificationView_Previews: PreviewProvider {
    static var previews: some View {
        DeviceNotificationView(deviceName: "MacBook Pro Microphone")
            .frame(width: 320, height: 80)
            .background(Color.black)
    }
}
#endif
