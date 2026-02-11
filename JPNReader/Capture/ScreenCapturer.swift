import Cocoa
import ScreenCaptureKit

struct ScreenCapturer {
    /// Captures a region of the screen as a CGImage using ScreenCaptureKit.
    /// - Parameters:
    ///   - rect: The rectangle in screen coordinates (AppKit, bottom-left origin).
    ///   - screen: The screen the selection was made on.
    ///   - completion: Called with the captured CGImage, or nil on failure.
    static func capture(rect: NSRect, screen: NSScreen, completion: @escaping (CGImage?) -> Void) {
        Task {
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

                guard let display = content.displays.first(where: { $0.displayID == screen.displayID }) else {
                    DispatchQueue.main.async { completion(nil) }
                    return
                }

                let filter = SCContentFilter(display: display, excludingWindows: [])

                let config = SCStreamConfiguration()
                config.sourceRect = convertToCGCoordinates(rect: rect, screen: screen)
                config.width = Int(rect.width * screen.backingScaleFactor)
                config.height = Int(rect.height * screen.backingScaleFactor)
                config.pixelFormat = kCVPixelFormatType_32BGRA
                config.showsCursor = false

                let image = try await SCScreenshotManager.captureImage(
                    contentFilter: filter,
                    configuration: config
                )

                DispatchQueue.main.async { completion(image) }
            } catch {
                print("Screen capture failed: \(error.localizedDescription)")
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }

    /// Converts an AppKit rect (bottom-left origin) to CG coordinates (top-left origin).
    private static func convertToCGCoordinates(rect: NSRect, screen: NSScreen) -> CGRect {
        let screenHeight = screen.frame.height
        return CGRect(
            x: rect.origin.x - screen.frame.origin.x,
            y: screenHeight - (rect.origin.y - screen.frame.origin.y) - rect.height,
            width: rect.width,
            height: rect.height
        )
    }
}

// Helper to get the CGDirectDisplayID from an NSScreen
extension NSScreen {
    var displayID: CGDirectDisplayID {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return deviceDescription[key] as? CGDirectDisplayID ?? 0
    }
}
