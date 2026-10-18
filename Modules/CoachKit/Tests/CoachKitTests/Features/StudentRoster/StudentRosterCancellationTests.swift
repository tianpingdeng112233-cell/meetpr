import Foundation
import Testing

@testable import CoachKit

@MainActor
struct StudentRosterCancellationTests {
  @Test(arguments: [true, false])
  func cancelledRefreshKeepsLoadedRows(urlCancellation: Bool) async {
    let students = StubCoachPlanRepository(students: [CoachStudentFeatureFixtures.summary()])
    let model = makeModel(students)
    await model.refresh()
    let rows = model.rows
    #expect(!rows.isEmpty)
    await students.setError(urlCancellation ? URLError(.cancelled) : CancellationError())
    await model.refresh()
    #expect(model.state == .loaded)
    #expect(model.rows == rows)
  }

  @Test func cancelledInitialLoadReturnsToIdle() async {
    let students = StubCoachPlanRepository(students: [], error: URLError(.cancelled))
    let model = makeModel(students)
    await model.refresh()
    #expect(model.state == .idle)
  }

  @Test func realRefreshFailureStillFails() async {
    let students = StubCoachPlanRepository(students: [CoachStudentFeatureFixtures.summary()])
    let model = makeModel(students)
    await model.refresh()
    await students.setError(URLError(.notConnectedToInternet))
    await model.refresh()
    #expect(model.state.isFailure)
  }

  @Test func loadedRosterStaysVisibleUntilRefreshIsCancelled() async {
    let students = StubCoachPlanRepository(students: [CoachStudentFeatureFixtures.summary()])
    let model = makeModel(students)
    await model.refresh()
    let rows = model.rows
    await students.suspendNextFetch()
    let refresh = Task { await model.refresh() }
    while !(await students.isSuspended) { await Task.yield() }
    #expect(model.state == .loaded)
    #expect(model.rows == rows)
    refresh.cancel()
    await refresh.value
    #expect(model.state == .loaded)
    #expect(model.rows == rows)
  }

  private func makeModel(_ students: StubCoachPlanRepository) -> StudentRosterViewModel {
    StudentRosterViewModel(
      students: students, plans: StubStudentPlanRepository(plans: [:]),
      trainingLogs: StubTrainingLogRepository(logs: []), feedback: StubFeedbackRepository())
  }
}
