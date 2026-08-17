import Testing
@testable import GlobeSwitchCore

@Test func globePressTriggersOnlyOnDownTransition() {
    var state = GlobePressState()
    let firstDown = state.update(isDown: true)
    let repeatedDown = state.update(isDown: true)
    let release = state.update(isDown: false)
    let secondDown = state.update(isDown: true)
    #expect(firstDown)
    #expect(!repeatedDown)
    #expect(!release)
    #expect(secondDown)
}

@Test func pairAlternatesBothDirections() {
    let pair = InputSourcePair(firstID: "ABC", secondID: "UA")
    #expect(pair.nextID(currentID: "ABC") == "UA")
    #expect(pair.nextID(currentID: "UA") == "ABC")
    #expect(pair.nextID(currentID: nil) == "ABC")
}
