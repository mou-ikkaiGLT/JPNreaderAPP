import Cocoa

/// NSWindow subclass that closes when the user presses Escape.
class EscapableWindow: NSWindow {
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            close()
        } else {
            super.keyDown(with: event)
        }
    }

    override var canBecomeKey: Bool { true }
}
