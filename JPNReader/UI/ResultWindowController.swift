import Cocoa

class ResultWindowController {
    private static var activeWindows: [NSWindow] = []

    static func show(text: String) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 350, height: 250),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        window.title = "JPN Reader — Detected Text"
        window.level = .floating
        window.isReleasedWhenClosed = false
        window.center()
        window.minSize = NSSize(width: 200, height: 120)

        let contentView = NSView(frame: window.contentView!.bounds)
        contentView.autoresizingMask = [.width, .height]

        // Copy button
        let copyButton = NSButton(frame: .zero)
        copyButton.title = "Copy to Clipboard"
        copyButton.bezelStyle = .rounded
        copyButton.translatesAutoresizingMaskIntoConstraints = false
        copyButton.target = ResultWindowHelper.shared
        copyButton.action = #selector(ResultWindowHelper.copyText(_:))
        contentView.addSubview(copyButton)

        // Scrollable text view
        let scrollView = NSScrollView(frame: .zero)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .noBorder

        let textView = NSTextView(frame: .zero)
        textView.isEditable = false
        textView.isSelectable = true
        textView.font = NSFont.systemFont(ofSize: 16)
        textView.string = text
        textView.textContainerInset = NSSize(width: 8, height: 8)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = .width
        textView.textContainer?.widthTracksTextView = true
        textView.identifier = NSUserInterfaceItemIdentifier("resultTextView")

        scrollView.documentView = textView
        contentView.addSubview(scrollView)

        // Layout
        NSLayoutConstraint.activate([
            copyButton.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            copyButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),

            scrollView.topAnchor.constraint(equalTo: copyButton.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])

        window.contentView = contentView
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        activeWindows.append(window)
    }
}

// Helper class for button actions (needs to be an NSObject for @objc selectors)
class ResultWindowHelper: NSObject {
    static let shared = ResultWindowHelper()

    @objc func copyText(_ sender: NSButton) {
        guard let window = sender.window,
              let contentView = window.contentView,
              let scrollView = contentView.subviews.compactMap({ $0 as? NSScrollView }).first,
              let textView = scrollView.documentView as? NSTextView else { return }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(textView.string, forType: .string)

        // Brief visual feedback
        let original = sender.title
        sender.title = "Copied!"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            sender.title = original
        }
    }
}
