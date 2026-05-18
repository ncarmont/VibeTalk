import Cocoa
import CoreGraphics

class TextInjector {
    /// Paste text into the target app by restoring focus, setting clipboard, simulating Cmd+V
    static func inject(_ text: String, targetApp: NSRunningApplication?) {
        let pasteboard = NSPasteboard.general
        let previousContent = pasteboard.string(forType: .string)

        // Re-activate the app the user was typing in
        if let app = targetApp {
            if #available(macOS 14.0, *) {
                app.activate()
            } else {
                app.activate(options: .activateIgnoringOtherApps)
            }
        }

        // Wait for the app to come to front, then paste
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)

            // Brief delay for pasteboard sync
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                // Simulate Cmd+V
                let source = CGEventSource(stateID: .combinedSessionState)

                let vKeyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
                let vKeyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)

                vKeyDown?.flags = .maskCommand
                vKeyUp?.flags = .maskCommand

                vKeyDown?.post(tap: .cghidEventTap)
                vKeyUp?.post(tap: .cghidEventTap)

                // Restore previous clipboard after paste completes
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                    if let previous = previousContent {
                        pasteboard.clearContents()
                        pasteboard.setString(previous, forType: .string)
                    }
                }
            }
        }
    }
}
