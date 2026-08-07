import Testing

@testable import StudentKit

@Suite struct HoldToCompleteGestureStateTests {
  @Test func movingBackInsideAfterLeavingBoundsDoesNotRestartHold() {
    var state = HoldToCompleteGestureState()

    #expect(state.dragChanged(isWithinBounds: true) == .begin)
    #expect(state.dragChanged(isWithinBounds: false) == .cancel)
    #expect(state.dragChanged(isWithinBounds: true) == nil)
    #expect(state.phase == .cancelledUntilEnded)
    #expect(state.dragEnded() == .reset)
    #expect(state.dragChanged(isWithinBounds: true) == .begin)
  }

  @Test func movingAfterCompletionDoesNotCompleteTwice() {
    var state = HoldToCompleteGestureState()

    #expect(state.dragChanged(isWithinBounds: true) == .begin)
    #expect(state.holdCompleted() == .complete)
    #expect(state.dragChanged(isWithinBounds: true) == nil)
    #expect(state.dragChanged(isWithinBounds: false) == nil)
    #expect(state.holdCompleted() == nil)
    #expect(state.phase == .completedUntilEnded)
  }

  @Test func endingHoldBeforeCompletionCancelsAndResets() {
    var state = HoldToCompleteGestureState()

    #expect(state.dragChanged(isWithinBounds: true) == .begin)
    #expect(state.dragEnded() == .cancel)
    #expect(state.phase == .idle)
    #expect(state.holdCompleted() == nil)
  }

  @Test func oneGestureProducesExactlyOneCompletionAction() {
    var state = HoldToCompleteGestureState()

    _ = state.dragChanged(isWithinBounds: true)
    let actions = [
      state.holdCompleted(),
      state.holdCompleted(),
      state.holdCompleted(),
    ]
    _ = state.dragChanged(isWithinBounds: true)
    _ = state.dragEnded()

    #expect(actions.count { $0 == .complete } == 1)
  }
}
