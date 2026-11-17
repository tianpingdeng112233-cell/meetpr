import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import CoachKit

/// Current and a later published empty cycle are both available at the public boundary.
struct HandoffCoachPlanRepository: StudentPlanRepository {
  let current: StudentPlanView
  let upcoming = StudentPlanView(
    cycleID: UUID(), weekIndex: 1,
    startDate: .distantFuture, publishedAt: .distantFuture, days: [])
  func fetchCurrentPlan(studentID: UUID) async throws -> StudentPlanView? { current }
  func fetchCycleDays(studentID: UUID) async throws -> [StudentPlanDay] { current.days }
  func fetchPlan(id: UUID, studentID: UUID) async throws -> StudentPlanView? {
    id == current.cycleID ? current : upcoming
  }
}

@MainActor
@Test func handoffRosterUsesCurrentTrainingDaysRatherThanLatestPublished() async throws {
  let current = CoachStudentFeatureFixtures.plan()
  let model = StudentRosterViewModel(
    students: StubCoachPlanRepository(students: [CoachStudentFeatureFixtures.summary()]),
    plans: HandoffCoachPlanRepository(current: current),
    trainingLogs: StubTrainingLogRepository(logs: []), feedback: StubFeedbackRepository(),
    now: { CoachStudentFeatureFixtures.startDate })
  await model.refresh()
  #expect(model.rows.first?.trainingDays.map(\.date) == [current.days[1].date])
}

@MainActor
@Test func handoffDetailUsesCurrentExercisesRatherThanLatestPublished() async throws {
  let current = CoachStudentFeatureFixtures.plan()
  let model = StudentDetailViewModel(
    summary: CoachStudentFeatureFixtures.summary(),
    plans: HandoffCoachPlanRepository(current: current),
    trainingLogs: StubTrainingLogRepository(logs: []), feedback: StubFeedbackRepository(),
    now: { CoachStudentFeatureFixtures.startDate })
  await model.refresh()
  #expect(model.allPlanExercises.map(\.id) == [CoachStudentFeatureFixtures.planExerciseID])
}
