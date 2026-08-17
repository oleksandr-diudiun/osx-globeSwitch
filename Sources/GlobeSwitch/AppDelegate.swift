import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: GlobeSwitchController!
    private var statusMenu: StatusMenuController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        controller = GlobeSwitchController()
        statusMenu = StatusMenuController(controller: controller)
        controller.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller.stop()
        DiagnosticsLogger.shared.log("GlobeSwitch quit normally")
    }
}
