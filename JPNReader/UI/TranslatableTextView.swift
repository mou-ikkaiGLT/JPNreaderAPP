import Cocoa

/// NSTextView subclass that adds "Translate with Jisho" and "Translate with Google"
/// to the right-click context menu when text is selected.
class TranslatableTextView: NSTextView {

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = super.menu(for: event)

        guard selectedRange().length > 0 else { return menu }

        menu?.addItem(.separator())

        let jishoItem = NSMenuItem(
            title: "Translate with Jisho",
            action: #selector(translateWithJisho),
            keyEquivalent: ""
        )
        jishoItem.target = self
        menu?.addItem(jishoItem)

        let googleItem = NSMenuItem(
            title: "Translate with Google",
            action: #selector(translateWithGoogle),
            keyEquivalent: ""
        )
        googleItem.target = self
        menu?.addItem(googleItem)

        return menu
    }

    @objc private func translateWithJisho() {
        guard let text = selectedText() else { return }
        let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? text
        let url = URL(string: "https://jisho.org/search/\(encoded)")!
        WebPopupController.show(url: url, title: "Jisho — \(text)")
    }

    @objc private func translateWithGoogle() {
        guard let text = selectedText() else { return }
        let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? text
        let url = URL(string: "https://translate.google.com/?sl=ja&tl=en&text=\(encoded)")!
        WebPopupController.show(url: url, title: "Google Translate — \(text)")
    }

    private func selectedText() -> String? {
        let range = selectedRange()
        guard range.length > 0 else { return nil }
        return (string as NSString).substring(with: range)
    }
}
