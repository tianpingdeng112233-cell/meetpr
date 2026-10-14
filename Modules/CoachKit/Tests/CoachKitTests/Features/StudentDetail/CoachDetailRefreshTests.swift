import CoreModels
import Foundation
import Networking
import Testing
import ViewInspector

@testable import CoachKit

@MainActor
@Test func refreshShowsServerCatalogNameAndRemovesDeletedAddedSets() async throws {
  let sample = CoachDayDetailPresentationTests().fixture()
  let planDay = try #require(sample.planDay)
  let exerciseID = try #require(sample.allLogs.first { $0.adhoc }?.exerciseID)
  let remoteExercise = Exercise(
    id: exerciseID, name: "Server-only curl", nameEn: "Server-only curl",
    exerciseType: .accessory, isCompetitionLift: false, muscleGroups: [], equipment: [],
    createdAt: sample.date)
  let repository = CoachDetailReadFixture(logs: sample.allLogs, exercise: remoteExercise)
  let summary = CoachStudentFeatureFixtures.summary()
  let plan = StudentPlanView(cycleID: UUID(), weekIndex: 2, startDate: sample.date, days: [planDay])
  let viewModel = StudentDetailViewModel(
    summary: summary,
    plans: StubStudentPlanRepository(plans: [summary.id: plan]),
    trainingLogs: EmptyStudentTrainingLogRepository(), feedback: EmptyStudentFeedbackRepository(),
    planning: repository, now: { sample.date })
  await viewModel.refresh()
  let loaded = try #require(viewModel.executionDays.first { $0.planDay?.id == planDay.id })
  let inspected = try CoachDayDetailView(day: loaded).inspect()
  #expect(try inspected.find(text: "Server-only curl").string() == "Server-only curl")
  let retained = sample.allLogs.filter { $0.planExerciseID != nil && $0.setIndex < 3 }
  await repository.replaceLogs(retained)
  await viewModel.refresh()
  let refreshed = try #require(viewModel.executionDays.first { $0.planDay?.id == planDay.id })
  let cards = CoachDayDetailPresentation(day: refreshed)
  #expect(cards.added.isEmpty)
  #expect(cards.planned.first?.extra.isEmpty == true)
  #expect(refreshed.completedSetCount == 2)
}

private actor CoachDetailReadFixture: PlanRepository {
  var logs: [CoachSetLogDTO]
  let exercise: Exercise
  init(logs: [CoachSetLogDTO], exercise: Exercise) {
    self.logs = logs
    self.exercise = exercise
  }
  func replaceLogs(_ logs: [CoachSetLogDTO]) { self.logs = logs }
  func fetchCoachLogs(studentID: UUID, in range: ClosedRange<Date>) -> [CoachSetLogDTO]? { logs }
  func fetchStudents() -> [CoachStudentSummary] { [] }
  func fetchMainLiftCatalog() -> [Exercise] { [] }
  func fetchAccessoryExercises(filters: AccessoryFilters) -> [Exercise] { [exercise] }
  func publishPlan(plan: TrainingPlan, days: [PlanDay], exercises: [PlanExercise], sets: [PlanSet])
  {}
}
