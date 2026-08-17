public struct InputSourcePair: Equatable, Sendable {
    public let firstID: String
    public let secondID: String

    public init(firstID: String, secondID: String) {
        self.firstID = firstID
        self.secondID = secondID
    }

    public func nextID(currentID: String?) -> String {
        currentID == firstID ? secondID : firstID
    }
}
