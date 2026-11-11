import Foundation
import Testing

@testable import StudentKit

@MainActor
@Suite struct WorkoutCompletionFlowModelTests {
  @Test func untouchedCelebrationFinishesAfterFiveSeconds() async {
    var finished = 0
    let model = WorkoutCompletionFlowModel(initialPhase: .celebration)
    await model.autoClose(
      sleep: { duration in
        #expect(duration == .seconds(5))
        #expect(finished == 0)
      },
      onFinish: { finished += 1 }
    )
    #expect(finished == 1)
  }

  @Test func touchingCelebrationCancelsAutocloseButAllowsManualFinish() async {
    var finished = 0
    let model = WorkoutCompletionFlowModel(initialPhase: .celebration)
    await model.autoClose(
      sleep: { _ in model.touch() },
      onFinish: { finished += 1 }
    )
    #expect(finished == 0)
    #expect(!model.isAutoClosePending)
    model.finish { finished += 1 }
    #expect(finished == 1)
  }

  @Test func openingReportBeforeDeadlineKeepsItOpen() async {
    var finished = 0
    let model = WorkoutCompletionFlowModel(initialPhase: .celebration)
    await model.autoClose(
      sleep: { _ in model.openReview() },
      onFinish: { finished += 1 }
    )
    #expect(model.phase == .review)
    #expect(finished == 0)
  }

  @Test func bannerReviewDoesNotStartTimer() async {
    let model = WorkoutCompletionFlowModel(initialPhase: .review)
    await model.autoClose(
      sleep: { _ in Issue.record("Review must not schedule autoclose") },
      onFinish: { Issue.record("Review must remain open") }
    )
  }

  @Test func manualFinishDuringWaitIsNotRepeatedAtDeadline() async {
    var finished = 0
    let model = WorkoutCompletionFlowModel(initialPhase: .celebration)
    await model.autoClose(
      sleep: { _ in model.finish { finished += 1 } },
      onFinish: { finished += 1 }
    )
    #expect(finished == 1)
  }

  @Test func cancelledSleepDoesNotCloseFlow() async {
    let model = WorkoutCompletionFlowModel(initialPhase: .celebration)
    await model.autoClose(
      sleep: { _ in throw CancellationError() },
      onFinish: { Issue.record("Cancelled flow must not finish") }
    )
    #expect(!model.didFinish)
  }

}
