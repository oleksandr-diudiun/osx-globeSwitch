import Carbon
import Foundation
import GlobeSwitchCore

struct InputSourceSummary: Equatable, Sendable {
    let id: String
    let name: String
    let abbreviation: String
}

struct SwitchMeasurement: Sendable {
    let source: InputSourceSummary
    let durationMilliseconds: Double
}

enum InputSourceError: LocalizedError {
    case requiredSourcesUnavailable([String])
    case currentSourceUnavailable
    case selectionFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .requiredSourcesUnavailable(let ids):
            "Required input sources are unavailable: \(ids.joined(separator: ", "))"
        case .currentSourceUnavailable:
            "The current keyboard input source could not be read."
        case .selectionFailed(let status):
            "macOS rejected the input-source change (OSStatus \(status))."
        }
    }
}

final class InputSourceController {
    static let pair = InputSourcePair(
        firstID: "com.apple.keylayout.ABC",
        secondID: "com.apple.keylayout.Ukrainian-PC"
    )

    private var sourcesByID: [String: TISInputSource] = [:]

    init() {
        reload()
    }

    func reload() {
        let filter: [CFString: Any] = [
            kTISPropertyInputSourceCategory: kTISCategoryKeyboardInputSource as Any,
            kTISPropertyInputSourceIsEnabled: true,
            kTISPropertyInputSourceIsSelectCapable: true
        ]

        guard let unmanaged = TISCreateInputSourceList(filter as CFDictionary, false),
              let sources = unmanaged.takeRetainedValue() as? [TISInputSource] else {
            sourcesByID = [:]
            return
        }

        var refreshed: [String: TISInputSource] = [:]
        for source in sources {
            guard let id = stringProperty(source, kTISPropertyInputSourceID) else { continue }
            refreshed[id] = source
        }
        sourcesByID = refreshed
    }

    func currentSource() -> InputSourceSummary? {
        let source = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        return summary(for: source)
    }

    func toggle() throws -> SwitchMeasurement {
        let requiredIDs = [Self.pair.firstID, Self.pair.secondID]
        let missing = requiredIDs.filter { sourcesByID[$0] == nil }
        if !missing.isEmpty {
            reload()
            let stillMissing = requiredIDs.filter { sourcesByID[$0] == nil }
            if !stillMissing.isEmpty {
                throw InputSourceError.requiredSourcesUnavailable(stillMissing)
            }
        }

        guard let current = currentSource() else {
            throw InputSourceError.currentSourceUnavailable
        }
        let nextID = Self.pair.nextID(currentID: current.id)
        guard let next = sourcesByID[nextID] else {
            throw InputSourceError.requiredSourcesUnavailable([nextID])
        }

        let start = DispatchTime.now().uptimeNanoseconds
        let status = TISSelectInputSource(next)
        let end = DispatchTime.now().uptimeNanoseconds
        guard status == noErr else {
            throw InputSourceError.selectionFailed(status)
        }

        guard let selected = summary(for: next) else {
            throw InputSourceError.currentSourceUnavailable
        }
        return SwitchMeasurement(
            source: selected,
            durationMilliseconds: Double(end - start) / 1_000_000
        )
    }

    private func summary(for source: TISInputSource) -> InputSourceSummary? {
        guard let id = stringProperty(source, kTISPropertyInputSourceID) else { return nil }
        let name = stringProperty(source, kTISPropertyLocalizedName) ?? id
        let abbreviation: String
        switch id {
        case Self.pair.firstID: abbreviation = "EN"
        case Self.pair.secondID: abbreviation = "UA"
        default: abbreviation = "?"
        }
        return InputSourceSummary(id: id, name: name, abbreviation: abbreviation)
    }

    private func stringProperty(_ source: TISInputSource, _ key: CFString) -> String? {
        guard let raw = TISGetInputSourceProperty(source, key) else { return nil }
        return Unmanaged<AnyObject>.fromOpaque(raw).takeUnretainedValue() as? String
    }
}
