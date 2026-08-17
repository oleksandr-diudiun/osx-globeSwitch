import AppKit
import Combine

@MainActor
final class StatusMenuController: NSObject, NSMenuDelegate {
    private let controller: GlobeSwitchController
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private var cancellables: Set<AnyCancellable> = []

    init(controller: GlobeSwitchController) {
        self.controller = controller
        super.init()
        menu.delegate = self
        statusItem.menu = menu

        controller.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.updateStatusItem() }
            }
            .store(in: &cancellables)

        updateStatusItem()
    }

    func menuWillOpen(_ menu: NSMenu) {
        controller.refresh()
        rebuildMenu()
    }

    private func updateStatusItem() {
        guard let button = statusItem.button else { return }
        let active = controller.monitorState == .active
        button.image = NSImage(
            systemSymbolName: active ? "globe" : "globe.badge.chevron.backward",
            accessibilityDescription: "GlobeSwitch"
        )
        button.imagePosition = .imageLeading
        button.title = " \(controller.currentSource?.abbreviation ?? "?")"
        button.toolTip = controller.errorText ?? monitorDescription
        statusItem.length = NSStatusItem.variableLength
        button.invalidateIntrinsicContentSize()
    }

    private func rebuildMenu() {
        menu.removeAllItems()

        addDisabled("Current: \(controller.currentSource?.name ?? "Unknown")")
        addDisabled(monitorDescription)
        addDisabled(
            "Accessibility: \(controller.hasAccessibilityPermission ? "Granted" : "Required")"
        )
        addDisabled(
            "Input Monitoring: \(controller.hasInputMonitoringPermission ? "Granted" : "Required")"
        )
        if let milliseconds = controller.lastSwitchMilliseconds {
            addDisabled(String(format: "Last direct switch: %.3f ms", milliseconds))
        }
        if let error = controller.errorText {
            let item = addDisabled(error)
            item.image = NSImage(
                systemSymbolName: "exclamationmark.triangle.fill",
                accessibilityDescription: nil
            )
        }

        menu.addItem(.separator())

        let pause = NSMenuItem(
            title: controller.isPaused ? "Resume Globe Switching" : "Pause Globe Switching",
            action: #selector(togglePaused),
            keyEquivalent: ""
        )
        pause.target = self
        menu.addItem(pause)

        if !controller.systemGlobeActionIsDisabled {
            let warning = addDisabled("Set ‘Press Globe key to’ → Do Nothing")
            warning.image = NSImage(
                systemSymbolName: "exclamationmark.triangle.fill",
                accessibilityDescription: nil
            )
            let settings = NSMenuItem(
                title: "Open Keyboard Settings…",
                action: #selector(openKeyboardSettings),
                keyEquivalent: ""
            )
            settings.target = self
            menu.addItem(settings)
        }

        if controller.monitorState != .active {
            let permission = NSMenuItem(
                title: "Request Keyboard Access…",
                action: #selector(requestPermission),
                keyEquivalent: ""
            )
            permission.target = self
            menu.addItem(permission)
        }

        let test = NSMenuItem(
            title: "Test ABC ↔ Ukrainian",
            action: #selector(testSwitch),
            keyEquivalent: ""
        )
        test.target = self
        menu.addItem(test)

        let login = NSMenuItem(
            title: controller.launchAgentManager.isInstalled
                ? "Disable Launch at Login"
                : "Enable Launch at Login",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        login.target = self
        menu.addItem(login)

        let diagnostics = NSMenuItem(
            title: "Show Diagnostics Log",
            action: #selector(showDiagnostics),
            keyEquivalent: ""
        )
        diagnostics.target = self
        menu.addItem(diagnostics)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit GlobeSwitch", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    private var monitorDescription: String {
        if controller.isPaused {
            return "Globe monitor: Paused"
        }
        return switch controller.monitorState {
        case .stopped: "Globe monitor: Stopped"
        case .permissionRequired: "Globe monitor: Keyboard access required"
        case .active: "Globe monitor: Active (switch on key-down)"
        case .failed(let message): "Globe monitor: \(message)"
        }
    }

    @discardableResult
    private func addDisabled(_ title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        menu.addItem(item)
        return item
    }

    @objc private func requestPermission() {
        controller.requestKeyboardPermission()
    }

    @objc private func togglePaused() {
        controller.togglePaused()
        rebuildMenu()
    }

    @objc private func testSwitch() {
        controller.testSwitch()
    }

    @objc private func openKeyboardSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.Keyboard-Settings.extension") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if controller.launchAgentManager.isInstalled {
                try controller.launchAgentManager.uninstall()
            } else {
                try controller.launchAgentManager.install()
            }
        } catch {
            DiagnosticsLogger.shared.log(error.localizedDescription, level: .error)
        }
        rebuildMenu()
    }

    @objc private func showDiagnostics() {
        NSWorkspace.shared.activateFileViewerSelecting([DiagnosticsLogger.shared.logURL])
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
