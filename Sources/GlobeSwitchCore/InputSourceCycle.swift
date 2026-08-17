public struct InputSourceCycle: Equatable, Sendable {
    public let sourceIDs: [String]

    public init(sourceIDs: [String]) {
        self.sourceIDs = sourceIDs
    }

    public func nextID(currentID: String?) -> String? {
        guard let first = sourceIDs.first else { return nil }
        guard let currentID,
              let currentIndex = sourceIDs.firstIndex(of: currentID) else {
            return first
        }
        return sourceIDs[(currentIndex + 1) % sourceIDs.count]
    }
}

public enum InputSourceSelection {
    public static func reconcile(
        availableIDs: [String],
        preferredIDs: [String]?
    ) -> [String] {
        guard let preferredIDs else { return availableIDs }

        let preferred = Set(preferredIDs)
        let availablePreferred = availableIDs.filter(preferred.contains)
        if availableIDs.count < 2 { return availableIDs }
        if availablePreferred.count >= 2 {
            return availablePreferred
        }
        return availableIDs
    }
}
