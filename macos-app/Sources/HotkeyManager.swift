import Cocoa
import CoreGraphics

class HotkeyManager {
    var onToggle: (() -> Void)?
    var onPasteLatestScreenshot: (() -> Void)?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var globalMonitor: Any?
    private var globalFlagsMonitor: Any?
    private var localMonitor: Any?
    private var fnKeyDown = false
    private(set) var eventTapActive = false
    private(set) var diagnosticLog: [String] = []

    var inputMonitoringGranted: Bool { CGPreflightListenEventAccess() }

    private func log(_ msg: String) {
        let entry = "\(Date()): \(msg)"
        diagnosticLog.append(entry)
    }

    var onEventTapActivated: (() -> Void)?

    func start() {
        let trusted = AXIsProcessTrusted()
        let inputMonOK = CGPreflightListenEventAccess()
        log("AXIsProcessTrusted = \(trusted), InputMonitoring = \(inputMonOK)")

        if trusted {
            installEventTap()
        } else {
            // Prompt adds the app to the Accessibility list if it's absent
            promptAccessibility()
            log("Skipping event tap — no accessibility")
        }

        if !inputMonOK {
            log("Input Monitoring not granted — global NSEvent monitors will not fire")
        }

        installNSEventMonitors()
    }

    // MARK: - CGEvent Tap

    private func installEventTap() {
        // Clean up existing
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            self.runLoopSource = nil
        }
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            self.eventTap = nil
        }
        eventTapActive = false

        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)

        let callback: CGEventTapCallBack = { proxy, type, event, refcon -> Unmanaged<CGEvent>? in
            guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
            let mgr = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()

            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                mgr.log("Event tap was disabled by system, re-enabling")
                if let tap = mgr.eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
                return Unmanaged.passUnretained(event)
            }

            if type == .keyDown {
                let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
                let flags = event.flags

                if keyCode == 49 && flags.contains(.maskSecondaryFn) {
                    mgr.log("fn+Space via event tap")
                    DispatchQueue.main.async { mgr.onToggle?() }
                    return nil
                }
                if keyCode == 34 && flags.contains(.maskSecondaryFn) {
                    mgr.log("fn+i via event tap")
                    DispatchQueue.main.async { mgr.onPasteLatestScreenshot?() }
                    return nil
                }
                if keyCode == 49 && flags.contains(.maskControl) && flags.contains(.maskShift) {
                    mgr.log("Ctrl+Shift+Space via event tap")
                    DispatchQueue.main.async { mgr.onToggle?() }
                    return nil
                }
            }

            return Unmanaged.passUnretained(event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            log("FAILED to create event tap! Accessibility=\(AXIsProcessTrusted())")
            return
        }

        self.eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        eventTapActive = true
        log("Event tap ACTIVE — global hotkeys should work")
        DispatchQueue.main.async { self.onEventTapActivated?() }
    }

    // MARK: - NSEvent Monitors

    private func installNSEventMonitors() {
        if let m = globalMonitor { NSEvent.removeMonitor(m); globalMonitor = nil }
        if let m = globalFlagsMonitor { NSEvent.removeMonitor(m); globalFlagsMonitor = nil }
        if let m = localMonitor { NSEvent.removeMonitor(m); localMonitor = nil }

        // Track fn key state globally — on Apple Silicon / modern macOS, fn is NOT included
        // in keyDown.modifierFlags for global monitors, so we must track it via flagsChanged.
        globalFlagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self = self else { return }
            self.fnKeyDown = event.modifierFlags.contains(.function)
        }

        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return }
            // Use tracked fnKeyDown because event.modifierFlags.function is stripped in global keyDown events
            if self.isHotkeyGlobal(event) {
                self.log("Hotkey via global NSEvent monitor")
                DispatchQueue.main.async { self.onToggle?() }
            } else if self.isLatestScreenshotHotkeyGlobal(event) {
                self.log("fn+i via global NSEvent monitor")
                DispatchQueue.main.async { self.onPasteLatestScreenshot?() }
            }
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if let self = self, self.isHotkey(event) {
                self.log("Hotkey via local NSEvent monitor")
                DispatchQueue.main.async { self.onToggle?() }
                return nil
            }
            if let self = self, self.isLatestScreenshotHotkey(event) {
                self.log("fn+i via local NSEvent monitor")
                DispatchQueue.main.async { self.onPasteLatestScreenshot?() }
                return nil
            }
            return event
        }

        log("NSEvent monitors installed")
    }

    private func isHotkey(_ event: NSEvent) -> Bool {
        let m = event.modifierFlags
        if event.keyCode == 49 && m.contains(.function) { return true }
        if event.keyCode == 49 && m.contains(.control) && m.contains(.shift) { return true }
        return false
    }

    private func isLatestScreenshotHotkey(_ event: NSEvent) -> Bool {
        event.keyCode == 34 && event.modifierFlags.contains(.function)
    }

    // Global variants use tracked fnKeyDown because macOS strips fn from keyDown.modifierFlags
    // in global monitors on Apple Silicon / Ventura+. Also query hardware state directly as
    // a fallback for when flagsChanged arrives after keyDown (race condition on some Macs).
    private func isFnCurrentlyHeld() -> Bool {
        fnKeyDown || CGEventSource.flagsState(.hidSystemState).contains(.maskSecondaryFn)
    }

    private func isHotkeyGlobal(_ event: NSEvent) -> Bool {
        let m = event.modifierFlags
        if event.keyCode == 49 && isFnCurrentlyHeld() { return true }
        if event.keyCode == 49 && m.contains(.control) && m.contains(.shift) { return true }
        return false
    }

    private func isLatestScreenshotHotkeyGlobal(_ event: NSEvent) -> Bool {
        event.keyCode == 34 && isFnCurrentlyHeld()
    }

    private func promptAccessibility() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(opts)
    }

    func retryWithAccessibility() {
        guard AXIsProcessTrusted() else { return }
        // If the tap is missing or no longer enabled (happens when Accessibility is toggled
        // off/on — macOS kills the CFMachPort but our eventTapActive flag stays true), do a
        // full tear-down and recreate so the new session picks up a fresh port.
        let tapCurrentlyEnabled = eventTap.map { CGEvent.tapIsEnabled(tap: $0) } ?? false
        if !eventTapActive || !tapCurrentlyEnabled {
            log("Reinstalling event tap (active=\(eventTapActive), enabled=\(tapCurrentlyEnabled))")
            installEventTap()
        }
    }

    deinit {
        if let source = runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let m = globalMonitor { NSEvent.removeMonitor(m) }
        if let m = globalFlagsMonitor { NSEvent.removeMonitor(m) }
        if let m = localMonitor { NSEvent.removeMonitor(m) }
    }
}
