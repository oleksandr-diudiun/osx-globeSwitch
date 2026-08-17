import ApplicationServices
import Foundation
import GlobeSwitchCore

enum EventMonitorState: Equatable, Sendable {
    case stopped
    case permissionRequired
    case active
    case failed(String)
}

final class GlobeEventMonitor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var pressState = GlobePressState()
    private let onPress: () -> Void
    private let onStateChange: (EventMonitorState) -> Void

    init(
        onPress: @escaping () -> Void,
        onStateChange: @escaping (EventMonitorState) -> Void
    ) {
        self.onPress = onPress
        self.onStateChange = onStateChange
    }

    var isActive: Bool {
        eventTap.map(CGEvent.tapIsEnabled(tap:)) ?? false
    }

    func start() {
        guard eventTap == nil else { return }

        let mask = CGEventMask(1) << CGEventType.flagsChanged.rawValue
        let userInfo = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: globeEventTapCallback,
            userInfo: userInfo
        ) else {
            onStateChange(.permissionRequired)
            return
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            onStateChange(.failed("Could not attach the keyboard event tap to the run loop."))
            return
        }

        eventTap = tap
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        onStateChange(.active)
    }

    func stop() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        runLoopSource = nil
        eventTap = nil
        pressState = GlobePressState()
        onStateChange(.stopped)
    }

    func retry() {
        if eventTap == nil {
            start()
        } else if let eventTap, !CGEvent.tapIsEnabled(tap: eventTap) {
            CGEvent.tapEnable(tap: eventTap, enable: true)
        }
    }

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
                onStateChange(.active)
            }
            return Unmanaged.passUnretained(event)
        }

        guard type == .flagsChanged else {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        guard keyCode == 63 else {
            return Unmanaged.passUnretained(event)
        }

        let isDown = event.flags.contains(.maskSecondaryFn)
        if pressState.update(isDown: isDown) {
            // This callback is an active tap. Selecting the source before returning
            // keeps the next key event ordered after the language change.
            onPress()
        }
        return Unmanaged.passUnretained(event)
    }
}

private let globeEventTapCallback: CGEventTapCallBack = { _, type, event, userInfo in
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let monitor = Unmanaged<GlobeEventMonitor>.fromOpaque(userInfo).takeUnretainedValue()
    return monitor.handle(type: type, event: event)
}
