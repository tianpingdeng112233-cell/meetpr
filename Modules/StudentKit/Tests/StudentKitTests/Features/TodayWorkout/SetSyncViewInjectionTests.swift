import Foundation
import SwiftUI
import Testing

@testable import StudentKit

@Suite @MainActor struct SetSyncViewInjectionTests {
  @Test func workoutViewPassesQueueAcrossItsHostingBoundary() async throws {
    let student = StudentDemoSeed.studentID
    let plan = StudentAddedTestPlan.unsettledDemo()
    let queue = try SetSyncQueue(studentID: student, storage: MemorySetSyncStorage()) { _ in
      throw URLError(.notConnectedToInternet)
    }
    let view = TodayWorkoutView(
      studentID: student, setSyncQueue: queue,
      plans: InMemoryStudentPlanRepository(store: TestStudentPlanStore(seed: [student: plan])),
      logs: OfflineSetTestRepository())
    let state = try #require(
      Mirror(reflecting: view).descendant("_viewModel") as? State<TodayWorkoutViewModel>)
    let model = state.wrappedValue
    await model.load(dayID: plan.days[0].id, studentID: student)
    #expect(await model.commitSet(rowIndex: 0))
    #expect(queue.pendingCount == 1)
    #expect(model.currentDrafts?.first?.completed == true)
    #expect(model.actionErrorMessage == nil)
  }
}
