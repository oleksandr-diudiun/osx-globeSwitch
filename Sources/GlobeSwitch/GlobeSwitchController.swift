@preconcurrency import ApplicationServices
import Carbon
import Combine
import Foundation

@MainActor
final class GlobeSwitchController: ObservableObject {
    @Published private(set) var monitorState: EventMonitorState = .stopped
    @Published private(set) var currentSource: InputSourceSummary?
    @Published private(set) var lastSwitchMilliseconds: Double?
    @Published private(set) var errorText: String?
    @Published private(set) var switchCount = 0
    @Published private(set) var isPaused = false

    let launchAgentManager = LaunchAgentManager()

    private let inputSources = InputSourceController()
    private var eventMonitor: GlobeEventMonitor!
    private var permissionRetryTask: Task<Void, Never>?
    private var sourceObserver: NSObjectProtocol?

    init() {
        currentSource = inputSources.currentSource()
        eventMonitor = GlobeEventMonitor(
            onPress: { [weak self] in self?.switchImmediately() },
            onStateChange: { [weak self] state in self?.monitorState = state }
        )
    }

    var systemGlobeActionIsDisabled: Bool {
        CFPreferencesGetAppIntegerValue(
            "AppleFnUsageType" as CFString,
            "com.apple.HIToolbox" as CFString,
            nil
        ) == 0
    }

    var hasKeyboardPermission: Bool {
        AXIsProcessTrusted() || CGPreflightListenEventAccess()
    }

    var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }

    var hasInputMonitoringPermission: Bool {
        CGPreflightListenEventAccess()
    }

    func start() {
        DiagnosticsLogger.shared.log("GlobeSwitch launched")
        registerForInputSourceChanges()
        eventMonitor.start()
        startPermissionRetryTimerIfNeeded()
    }

    func stop() {
        permissionRetryTask?.cancel()
        permissionRetryTask = nil
        if let sourceObserver {
            DistributedNotificationCenter.default().removeObserver(sourceObserver)
        }
        sourceObserver = nil
        eventMonitor.stop()
    }

    func requestKeyboardPermission() {
        DiagnosticsLogger.shared.log("Requesting keyboard access")
        _ = CGRequestListenEventAccess()
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)
        startPermissionRetryTimerIfNeeded()
    }

    func testSwitch() {
        switchImmediately()
    }

    func refresh() {
        inputSources.reload()
        currentSource = inputSources.currentSource()
        if !isPaused, !eventMonitor.isActive {
            eventMonitor.retry()
        }
    }

    func togglePaused() {
        isPaused.toggle()
        if isPaused {
            permissionRetryTask?.cancel()
            permissionRetryTask = nil
            eventMonitor.stop()
        } else {
            eventMonitor.start()
            startPermissionRetryTimerIfNeeded()
        }
    }

    private func switchImmediately() {
        do {
            let measurement = try inputSources.toggle()
            // Keep the event callback hot: UI and diagnostics work is deferred
            // until after this input event returns to the system.
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.currentSource = measurement.source
                self.lastSwitchMilliseconds = measurement.durationMilliseconds
                self.switchCount += 1
                self.errorText = nil
            }
        } catch {
            let message = error.localizedDescription
            DispatchQueue.main.async { [weak self] in
                self?.errorText = message
                DiagnosticsLogger.shared.log(message, level: .error)
            }
        }
    }

    private func registerForInputSourceChanges() {
        let name = Notification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String)
        sourceObserver = DistributedNotificationCenter.default().addObserver(
            forName: name,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.currentSource = self?.inputSources.currentSource()
            }
        }
    }

    private func startPermissionRetryTimerIfNeeded() {
        guard !isPaused, monitorState != .active, permissionRetryTask == nil else { return }
        permissionRetryTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self, !Task.isCancelled else { return }
                self.eventMonitor.retry()
                if self.eventMonitor.isActive {
                    self.permissionRetryTask = nil
                    return
                }
            }
        }
    }
}
