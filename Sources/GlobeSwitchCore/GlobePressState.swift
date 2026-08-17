public struct GlobePressState: Sendable {
    private var isDown = false

    public init() {}

    /// Returns true only for the transition from released to pressed.
    /// GlobeSwitch deliberately switches on key-down, before the next character.
    public mutating func update(isDown newValue: Bool) -> Bool {
        defer { isDown = newValue }
        return newValue && !isDown
    }
}
