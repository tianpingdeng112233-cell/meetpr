import Foundation
import SwiftUI
import Testing
import ViewInspector

@testable import StudentKit

@Suite @MainActor struct VideoCompletionRewardRouteTests {
  @Test(arguments: [true, false])
  func actualRewardCloseCallbackKeepsWaitingDayAndPreservesOrdinaryNavigation(waiting: Bool)
    async throws
  {
    let student = UUID()
    let plan = StudentAddedTestPlan.unsettledDemo()
    let day = try #require(plan.days.dropFirst().first)
    let plans = InMemoryStudentPlanRepository(store: TestStudentPlanStore(seed: [student: plan]))
    let queue = try SetSyncQueue(studentID: student, storage: MemorySetSyncStorage()) {
      .planned($0.plannedLog)
    }
    if waiting {
      try queue.completionGate.request(dayID: day.id)
      try queue.completionGate.waitForVideos(
        dayID: day.id, trainingDate: day.scheduledDate, startedAt: Date())
    }
    var todayNavigations = 0
    let harness = VideoUploadHarness()
    let view = TodayWorkoutView(
      studentID: student, setSyncQueue: queue, plans: plans,
      logs: InMemoryStudentTrainingLogRepository(),
      videoUploads: VideoUploadServices(manager: harness.manager),
      planHandoff: TodayWorkoutPlanHandoff(plan: plan, dayID: day.id, existingLogs: []),
      onReturnToToday: { todayNavigations += 1 })
    let state = try #require(
      Mirror(reflecting: view).descendant("_viewModel") as? State<TodayWorkoutViewModel>)
    let model = state.wrappedValue
    await model.load(dayID: day.id, studentID: student)
    model.completionPhase = .celebration
    // Invoke the actual callback handed to the reward sheet, not a duplicate route predicate.
    let flow = try view.completionFlow(phase: .celebration).inspect()
      .find(WorkoutCompletionFlowView.self).actualView()
    flow.onFinish()
    #expect(todayNavigations == (waiting ? 0 : 1))
    #expect(model.completionPhase == nil)
    #expect(
      UserDefaultsSessionReviewStore().didCompleteReview(
        studentId: student, date: day.scheduledDate))
    if waiting {
      #expect(queue.completionGate.pendingDays == [day.id])
      guard case .loaded(let visibleDay, _) = model.state else {
        Issue.record("Waiting day must stay loaded after closing the reward")
        return
      }
      #expect(visibleDay.id == day.id)
    }
  }
}
