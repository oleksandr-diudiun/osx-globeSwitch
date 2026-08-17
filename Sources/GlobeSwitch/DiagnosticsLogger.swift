import Foundation
import OSLog

enum DiagnosticLevel: String {
    case info = "INFO"
    case error = "ERROR"
}

final class DiagnosticsLogger: @unchecked Sendable {
    static let shared = DiagnosticsLogger()

    private let logger = Logger(subsystem: "com.alexd.sound.GlobeSwitch", category: "controller")
    private let lock = NSLock()
    private let dateFormatter = ISO8601DateFormatter()
    let logURL: URL

    private init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = base.appendingPathComponent("GlobeSwitch", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        logURL = directory.appendingPathComponent("diagnostics.log")
    }

    func log(_ message: String, level: DiagnosticLevel = .info) {
        switch level {
        case .info: logger.info("\(message, privacy: .public)")
        case .error: logger.error("\(message, privacy: .public)")
        }

        let line = "\(dateFormatter.string(from: Date())) [\(level.rawValue)] \(message)\n"
        guard let data = line.data(using: .utf8) else { return }

        lock.lock()
        defer { lock.unlock() }
        if !FileManager.default.fileExists(atPath: logURL.path) {
            fileManagerCreateLogFile()
        }
        do {
            let handle = try FileHandle(forWritingTo: logURL)
            try handle.seekToEnd()
            try handle.write(contentsOf: data)
            try handle.close()
        } catch {
            logger.error("Could not append diagnostics: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func fileManagerCreateLogFile() {
        _ = FileManager.default.createFile(atPath: logURL.path, contents: nil)
    }
}
