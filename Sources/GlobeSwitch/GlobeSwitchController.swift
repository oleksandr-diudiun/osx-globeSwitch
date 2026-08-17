@preconcurrency import ApplicationServices
import Carbon
import Combine
import Foundation
import GlobeSwitchCore

@MainActor
final class GlobeSwitchController: ObservableObject {
    @Published private(set) var monitorState: EventMonitorState = .stopped
    @Published private(set) var currentSource: InputSourceSummary?
    @Published private(set) var lastSwitchMilliseconds: Double?
    @Published private(set) var errorText: String?
    @Published private(set) var switchCount = 0
    @Published private(set) var isPaused = false
    @Published private(set) var availableSources: [InputSourceSummary] = []
    @Published private(set) var selectedSourceIDs: [String] = []

    let launchAgentManager = LaunchAgentManager()

    private let inputSources = InputSourceController()
    private let defaults = UserDefaults.standard
    private var eventMonitor: GlobeEventMonitor!
    private var permissionRetryTask: Task<Void, Never>?
    private var sourceObserver: NSObjectProtocol?

    private static let selectedSourceIDsKey = "selectedInputSourceIDs"

    init() {
        availableSources = inputSources.availableSources
        let preferredIDs = defaults.stringArray(forKey: Self.selectedSourceIDsKey)
        selectedSourceIDs = InputSourceSelection.reconcile(
            availableIDs: availableSources.map(\.id),
            preferredIDs: preferredIDs
        )
        if preferredIDs != nil, preferredIDs != selectedSourceIDs {
            defaults.set(selectedSourceIDs, forKey: Self.selectedSourceIDsKey)
        }
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
        CGPreflightListenEventAccess()
    }

    var hasInputMonitoringPermission: Bool {
        CGPreflightListenEventAccess()
    }

    func start() {
        DiagnosticsLogger.shared.log("GlobeSwitch launched")
        let availableDescription = availableSources
            .map { "\($0.name) [\($0.id)]" }
            .joined(separator: ", ")
        DiagnosticsLogger.shared.log("Available input sources: \(availableDescription)")
        DiagnosticsLogger.shared.log(
            "Selected Globe cycle: \(selectedSourceIDs.joined(separator: ", "))"
        )
        registerForInputSourceChanges()
        if !CGPreflightListenEventAccess() {
            DiagnosticsLogger.shared.log("Input Monitoring is not granted; requesting access")
            _ = CGRequestListenEventAccess()
        }
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
        startPermissionRetryTimerIfNeeded()
    }

    func testSwitch() {
        switchImmediately()
    }

    func refresh() {
        inputSources.reload()
        availableSources = inputSources.availableSources
        let reconciled = InputSourceSelection.reconcile(
            availableIDs: availableSources.map(\.id),
            preferredIDs: selectedSourceIDs
        )
        if reconciled != selectedSourceIDs {
            selectedSourceIDs = reconciled
            defaults.set(selectedSourceIDs, forKey: Self.selectedSourceIDsKey)
        }
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

    func toggleSourceSelection(id: String) {
        guard availableSources.contains(where: { $0.id == id }) else {
            errorText = "This input source is no longer enabled in macOS."
            refresh()
            return
        }

        var selected = Set(selectedSourceIDs)
        if selected.contains(id) {
            guard selected.count > 2 else {
                errorText = "Keep at least two input sources in the Globe cycle."
                return
            }
            selected.remove(id)
        } else {
            selected.insert(id)
        }

        selectedSourceIDs = availableSources.map(\.id).filter(selected.contains)
        defaults.set(selectedSourceIDs, forKey: Self.selectedSourceIDsKey)
        errorText = nil
        DiagnosticsLogger.shared.log(
            "Updated Globe cycle: \(selectedSourceIDs.joined(separator: ", "))"
        )
    }

    func isSourceSelected(id: String) -> Bool {
        selectedSourceIDs.contains(id)
    }

    private func switchImmediately() {
        do {
            let measurement = try inputSources.toggle(selectedIDs: selectedSourceIDs)
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
