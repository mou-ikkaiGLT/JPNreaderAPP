import Cocoa
import ScreenCaptureKit

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarController = StatusBarController()
        setupMainMenu()
        requestScreenCaptureAccess()
    }

    /// Creates a minimal main menu with an Edit submenu so that
    /// standard keyboard shortcuts (Cmd+C, Cmd+V, Cmd+A) work in text views.
    private func setupMainMenu() {
        let mainMenu = NSMenu()

        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")

        let editMenuItem = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        NSApp.mainMenu = mainMenu
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
