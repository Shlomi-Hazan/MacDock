import Testing
@testable import LifecycleState

@Test func defaultStateKeepsIdleTimerEnabled() {
    let state = KeepAwakeStateModel()
    #expect(!state.userEnabled)
    #expect(!state.appliedIdleTimerDisabled)
    #expect(!state.shouldDisableIdleTimer)
}

@Test func enabledPreferenceAppliesOnlyInForegroundActive() {
    var state = KeepAwakeStateModel()
    state.setUserEnabled(true)
    #expect(!state.appliedIdleTimerDisabled)
    state.setLifecycleState(.active)
    #expect(state.appliedIdleTimerDisabled)
    state.setLifecycleState(.inactive)
    #expect(!state.appliedIdleTimerDisabled)
    #expect(state.userEnabled)
}

@Test func disablingPreferenceRestoresNormalBehavior() {
    var state = KeepAwakeStateModel()
    state.setLifecycleState(.active)
    state.setUserEnabled(true)
    #expect(state.appliedIdleTimerDisabled)
    state.setUserEnabled(false)
    #expect(!state.appliedIdleTimerDisabled)
}

@Test func repeatedTransitionsAreIdempotent() {
    var state = KeepAwakeStateModel()
    state.setLifecycleState(.active)
    state.setLifecycleState(.active)
    state.setUserEnabled(true)
    state.setUserEnabled(true)
    #expect(state.appliedIdleTimerDisabled)
    state.setLifecycleState(.background)
    state.setLifecycleState(.background)
    #expect(!state.appliedIdleTimerDisabled)
    #expect(state.userEnabled)
}
