import Cocoa

class StatusBarController {
    private var statusItem: NSStatusItem
    private var screenSelector: ScreenSelector?

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.title = "JP"
            button.toolTip = "JPN Reader — Click to capture Japanese text"
        }

        setupMenu()
    }

    private func setupMenu() {
        let menu = NSMenu()

        let captureItem = NSMenuItem(title: "Capture Region", action: #selector(captureRegion), keyEquivalent: "j")
        captureItem.keyEquivalentModifierMask = [.command, .shift]
        captureItem.target = self
        menu.addItem(captureItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func captureRegion() {
        screenSelector = ScreenSelector { [weak self] capturedImage in
            self?.screenSelector = nil
            guard let image = capturedImage else { return }

            TextRecognizer.recognizeJapanese(from: image) { text in
                DispatchQueue.main.async {
                    guard !text.isEmpty else {
                        let alert = NSAlert()
                        alert.messageText = "No Japanese text detected"
                        alert.informativeText = "No text was found in the selected region."
                        alert.alertStyle = .informational
                        alert.runModal()
                        return
                    }
                    ResultWindowController.show(text: text)
                }
            }
        }
        screenSelector?.start()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
