import Cocoa

class ScreenSelector {
    private var overlayWindows: [OverlayWindow] = []
    private let completion: (CGImage?) -> Void

    init(completion: @escaping (CGImage?) -> Void) {
        self.completion = completion
    }

    func start() {
        // Create an overlay window on each screen
        for screen in NSScreen.screens {
            let window = OverlayWindow(screen: screen) { [weak self] selectedRect, screen in
                self?.dismissAll()
                guard let rect = selectedRect else {
                    self?.completion(nil)
                    return
                }
                self?.captureRegion(rect, on: screen)
            }
            overlayWindows.append(window)
            window.makeKeyAndOrderFront(nil)
        }
    }

    private func dismissAll() {
        for window in overlayWindows {
            window.orderOut(nil)
        }
        overlayWindows.removeAll()
    }

    private func captureRegion(_ rect: NSRect, on screen: NSScreen) {
        // Small delay to let overlay windows disappear
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            ScreenCapturer.capture(rect: rect, screen: screen) { image in
                self?.completion(image)
            }
        }
    }
}

// MARK: - Overlay Window

class OverlayWindow: NSWindow {
    private var selectionCompletion: ((NSRect?, NSScreen) -> Void)!
    private var targetScreen: NSScreen!

    convenience init(screen: NSScreen, completion: @escaping (NSRect?, NSScreen) -> Void) {
        self.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        self.selectionCompletion = completion
        self.targetScreen = screen
        self.level = .screenSaver
        self.isOpaque = false
        self.backgroundColor = .clear
        self.ignoresMouseEvents = false
        self.acceptsMouseMovedEvents = true
        self.hasShadow = false

        let selectionView = SelectionView(frame: screen.frame)
        selectionView.onSelectionComplete = { [weak self] rect in
            guard let self = self else { return }
            if let rect = rect {
                // Convert from window coordinates to screen coordinates
                let screenRect = NSRect(
                    x: self.targetScreen.frame.origin.x + rect.origin.x,
                    y: self.targetScreen.frame.origin.y + rect.origin.y,
                    width: rect.width,
                    height: rect.height
                )
                self.selectionCompletion(screenRect, self.targetScreen)
            } else {
                self.selectionCompletion(nil, self.targetScreen)
            }
        }
        self.contentView = selectionView
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            selectionCompletion(nil, targetScreen)
        }
    }
}

// MARK: - Selection View

class SelectionView: NSView {
    var onSelectionComplete: ((NSRect?) -> Void)?

    private var startPoint: NSPoint?
    private var currentRect: NSRect?

    override func draw(_ dirtyRect: NSRect) {
        // Semi-transparent dark overlay
        NSColor.black.withAlphaComponent(0.3).setFill()
        dirtyRect.fill()

        // Clear the selection area and draw a border
        if let rect = currentRect {
            NSColor.clear.setFill()
            rect.fill(using: .clear)

            NSColor.white.setStroke()
            let borderPath = NSBezierPath(rect: rect)
            borderPath.lineWidth = 2
            borderPath.stroke()

            // Dashed inner border
            NSColor.systemBlue.setStroke()
            let dashPath = NSBezierPath(rect: rect.insetBy(dx: 1, dy: 1))
            dashPath.lineWidth = 1
            dashPath.setLineDash([6, 3], count: 2, phase: 0)
            dashPath.stroke()
        }
    }

    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
    }

    override func mouseDragged(with event: NSEvent) {
        guard let start = startPoint else { return }
        let current = convert(event.locationInWindow, from: nil)

        let x = min(start.x, current.x)
        let y = min(start.y, current.y)
        let w = abs(current.x - start.x)
        let h = abs(current.y - start.y)

        currentRect = NSRect(x: x, y: y, width: w, height: h)
        needsDisplay = true
    }

    override func mouseUp(with event: NSEvent) {
        if let rect = currentRect, rect.width > 5, rect.height > 5 {
            onSelectionComplete?(rect)
        } else {
            onSelectionComplete?(nil)
        }
        startPoint = nil
        currentRect = nil
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .crosshair)
    }
}
