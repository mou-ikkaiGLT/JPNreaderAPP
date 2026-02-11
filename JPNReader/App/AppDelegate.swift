import Cocoa
import ScreenCaptureKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarController = StatusBarController()
        requestScreenCaptureAccess()
    }

    /// Triggers the screen capture permission prompt on first launch
    /// by requesting shareable content. This ensures the user sees the
    /// system dialog before they try to capture.
    private func requestScreenCaptureAccess() {
        Task {
            do {
                _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            } catch {
                print("Screen capture access not yet granted: \(error.localizedDescription)")
            }
        }
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
}
