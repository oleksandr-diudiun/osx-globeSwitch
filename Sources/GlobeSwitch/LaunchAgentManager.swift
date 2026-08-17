import Foundation

enum LaunchAgentError: LocalizedError {
    case executableUnavailable

    var errorDescription: String? {
        "The GlobeSwitch executable path is unavailable."
    }
}

final class LaunchAgentManager {
    static let label = "com.alexd.sound.GlobeSwitch"
    private let fileManager = FileManager.default

    var plistURL: URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
            .appendingPathComponent("\(Self.label).plist")
    }

    var isInstalled: Bool {
        fileManager.fileExists(atPath: plistURL.path)
    }

    func install() throws {
        guard let executableURL = Bundle.main.executableURL else {
            throw LaunchAgentError.executableUnavailable
        }
        let supportDirectory = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/GlobeSwitch", isDirectory: true)
        try fileManager.createDirectory(at: supportDirectory, withIntermediateDirectories: true)
        try fileManager.createDirectory(
            at: plistURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let plist: [String: Any] = [
            "Label": Self.label,
            "ProgramArguments": [executableURL.path],
            "RunAtLoad": true,
            "ProcessType": "Interactive",
            "StandardOutPath": supportDirectory.appendingPathComponent("launch-agent.out.log").path,
            "StandardErrorPath": supportDirectory.appendingPathComponent("launch-agent.err.log").path
        ]
        let data = try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )
        try data.write(to: plistURL, options: .atomic)
        DiagnosticsLogger.shared.log("Installed login LaunchAgent at \(plistURL.path)")
    }

    func uninstall() throws {
        if fileManager.fileExists(atPath: plistURL.path) {
            try fileManager.removeItem(at: plistURL)
        }
        DiagnosticsLogger.shared.log("Removed login LaunchAgent")
    }
}
