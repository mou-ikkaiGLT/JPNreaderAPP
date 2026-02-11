import Cocoa

/// Registers system-wide hotkeys using a CGEvent tap.
/// Requires Accessibility permission (System Settings → Privacy & Security → Accessibility).
class HotkeyManager {
    struct Hotkey {
        let keyCode: CGKeyCode
        let modifiers: CGEventFlags
        let action: () -> Void
    }

    fileprivate var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var hotkeys: [Hotkey] = []

    /// Registers a global hotkey.
    func register(keyCode: CGKeyCode, modifiers: CGEventFlags, action: @escaping () -> Void) {
        hotkeys.append(Hotkey(keyCode: keyCode, modifiers: modifiers, action: action))
    }

    /// Starts listening for global key events. Call after all hotkeys are registered.
    func start() {
        // Store self in a pointer so the C callback can access it
        let refcon = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue),
            callback: hotkeyCallback,
            userInfo: refcon
        ) else {
            print("HotkeyManager: Failed to create event tap. Ensure Accessibility access is granted.")
            promptAccessibilityPermission()
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    /// Checks if any registered hotkey matches the event.
    fileprivate func handleEvent(_ event: CGEvent) -> Bool {
        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = event.flags

        for hotkey in hotkeys {
            // Check modifier flags (mask out irrelevant bits like caps lock)
            let relevantMask: CGEventFlags = [.maskCommand, .maskShift, .maskAlternate, .maskControl]
            let eventMods = flags.intersection(relevantMask)
            let requiredMods = hotkey.modifiers.intersection(relevantMask)

            if keyCode == hotkey.keyCode && eventMods == requiredMods {
                DispatchQueue.main.async { hotkey.action() }
                return true // consume the event
            }
        }
        return false
    }

    private func promptAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    deinit {
        stop()
    }
}

// C-function callback for the CGEvent tap
private func hotkeyCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    // Re-enable the tap if it gets disabled (system can disable it under load)
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let refcon = refcon {
            let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
            if let tap = manager.eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
        }
        return Unmanaged.passUnretained(event)
    }

    guard type == .keyDown, let refcon = refcon else {
        return Unmanaged.passUnretained(event)
    }

    let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
    if manager.handleEvent(event) {
        return nil // consumed — don't pass to other apps
    }

    return Unmanaged.passUnretained(event)
}
