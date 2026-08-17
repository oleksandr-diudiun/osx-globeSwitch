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

@Test func cycleAdvancesAndWrapsAcrossThreeSources() {
    let cycle = InputSourceCycle(sourceIDs: ["EN", "UA", "DE"])
    #expect(cycle.nextID(currentID: "EN") == "UA")
    #expect(cycle.nextID(currentID: "UA") == "DE")
    #expect(cycle.nextID(currentID: "DE") == "EN")
    #expect(cycle.nextID(currentID: "FR") == "EN")
    #expect(cycle.nextID(currentID: nil) == "EN")
}

@Test func emptyCycleHasNoNextSource() {
    #expect(InputSourceCycle(sourceIDs: []).nextID(currentID: nil) == nil)
}

@Test func selectionUsesAvailableOrderAndDropsUnavailableSources() {
    let reconciled = InputSourceSelection.reconcile(
        availableIDs: ["EN", "UA", "DE"],
        preferredIDs: ["DE", "EN", "MISSING"]
    )
    #expect(reconciled == ["EN", "DE"])
}

@Test func selectionFallsBackToAllAvailableWhenFewerThanTwoRemain() {
    let reconciled = InputSourceSelection.reconcile(
        availableIDs: ["EN", "UA", "DE"],
        preferredIDs: ["MISSING", "UA"]
    )
    #expect(reconciled == ["EN", "UA", "DE"])
}

@Test func selectionKeepsTheOnlyAvailableSourceVisible() {
    let reconciled = InputSourceSelection.reconcile(
        availableIDs: ["EN"],
        preferredIDs: ["MISSING"]
    )
    #expect(reconciled == ["EN"])
}
