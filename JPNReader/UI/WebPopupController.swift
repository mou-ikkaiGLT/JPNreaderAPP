import Cocoa
import WebKit

class WebPopupController {
    private static var activeWindows: [NSWindow] = []

    static func show(url: URL, title: String) {
        let window = EscapableWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        window.title = title
        window.level = .floating
        window.isReleasedWhenClosed = false
        window.center()
        window.minSize = NSSize(width: 300, height: 200)

        let webView = WKWebView(frame: window.contentView!.bounds)
        webView.autoresizingMask = [.width, .height]
        webView.load(URLRequest(url: url))

        window.contentView = webView
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        activeWindows.append(window)
    }
}
