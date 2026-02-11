import Cocoa

class StatusBarController {
    private var statusItem: NSStatusItem
    private var screenSelector: ScreenSelector?
    private let hotkeyManager = HotkeyManager()

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.title = "JP"
            button.toolTip = "JPN Reader — Click to capture Japanese text"
        }

        setupMenu()
        setupGlobalHotkeys()
    }

    private func setupMenu() {
        let menu = NSMenu()

        let verticalItem = NSMenuItem(title: "Vertical Capture Region (⌘⇧J)", action: #selector(captureVertical), keyEquivalent: "")
        verticalItem.target = self
        menu.addItem(verticalItem)

        let horizontalItem = NSMenuItem(title: "Horizontal Capture Region (⌘⇧K)", action: #selector(captureHorizontal), keyEquivalent: "")
        horizontalItem.target = self
        menu.addItem(horizontalItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func setupGlobalHotkeys() {
        // Cmd+Shift+J → Vertical capture
        // J = keyCode 38
        hotkeyManager.register(
            keyCode: 38,
            modifiers: CGEventFlags([.maskCommand, .maskShift]),
            action: { [weak self] in self?.captureRegion(orientation: .vertical) }
        )

        // Cmd+Shift+K → Horizontal capture
        // K = keyCode 40
        hotkeyManager.register(
            keyCode: 40,
            modifiers: CGEventFlags([.maskCommand, .maskShift]),
            action: { [weak self] in self?.captureRegion(orientation: .horizontal) }
        )

        hotkeyManager.start()
    }

    @objc private func captureVertical() {
        captureRegion(orientation: .vertical)
    }

    @objc private func captureHorizontal() {
        captureRegion(orientation: .horizontal)
    }

    private func captureRegion(orientation: TextOrientation) {
        screenSelector = ScreenSelector { [weak self] capturedImage in
            self?.screenSelector = nil
            guard let image = capturedImage else { return }

            TextRecognizer.recognizeJapanese(from: image, orientation: orientation) { text in
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
