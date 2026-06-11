import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import CoachKit

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func growthFamilyMapKeepsMainLiftSlotsOnly() {
  let accessorySlot = StudentPlanExercise(
    id: UUID(uuidString: "02900000-0000-0000-0000-000000002001")!,
    exercise: Exercise(
      id: UUID(uuidString: "02900000-0000-0000-0000-000000002002")!,
      name: "腿举",
      exerciseType: .accessory,
      mainLiftFamily: nil,
      isCompetitionLift: false,
      muscleGroups: [.quad],
      equipment: [.machine],
      movementPattern: [.squat],
      createdAt: CoachStudentFeatureFixtures.startDate
    ),
    sequenceIndex: 1,
    prescribedSets: []
  )
  let day = StudentPlanDay(
    id: UUID(uuidString: "02900000-0000-0000-0000-000000002003")!,
    date: CoachStudentFeatureFixtures.startDate,
    exercises: [CoachStudentFeatureFixtures.exercise(), accessorySlot]
  )

  let families = StudentGrowthViewModel.familyByPlanExerciseID(days: [day])

  #expect(families == [CoachStudentFeatureFixtures.planExerciseID: .squat])
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func growthPointsRecomputeE1RMAndDropIneligibleLogs() {
  let base = CoachStudentFeatureFixtures.startDate
  let newer = growthLog(loggedAt: base.addingTimeInterval(3 * 86_400))
  let older = growthLog(loggedAt: base.addingTimeInterval(86_400), weightKg: 140, rpe: 8)
  let incomplete = growthLog(loggedAt: base.addingTimeInterval(2 * 86_400), completed: false)
  let unknownExercise = growthLog(
    loggedAt: base.addingTimeInterval(2 * 86_400),
    planExerciseID: UUID(uuidString: "02900000-0000-0000-0000-000000002004")!
  )
  // RPE > 10 is physically invalid — the calculator returns nil, never a
  // silent fallback (spec 028 boundary rules), so the point is dropped.
  let invalidRPE = growthLog(loggedAt: base.addingTimeInterval(2 * 86_400), rpe: 11)

  let points = StudentGrowthViewModel.makePoints(
    logs: [newer, incomplete, older, unknownExercise, invalidRPE],
    familyByPlanExerciseID: [CoachStudentFeatureFixtures.planExerciseID: .squat]
  )

  let squatPoints = points[.squat] ?? []
  #expect(points.count == 1)
  #expect(squatPoints.map(\.id) == [older.id, newer.id])
  let expectedOlder = E1RMCalculator.calculate(weightKg: 140, reps: 5, rpe: 8)
  let expectedNewer = E1RMCalculator.calculate(weightKg: 142.5, reps: 5, rpe: 8.5)
  #expect(squatPoints.map(\.e1RMKg) == [expectedOlder, expectedNewer].compactMap { $0 })
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func growthLoadFiltersByFamilyAndTimeWindow() async {
  let now = CoachStudentFeatureFixtures.startDate.addingTimeInterval(3 * 86_400)
  let recent = growthLog(loggedAt: now.addingTimeInterval(-2 * 86_400))
  let old = growthLog(loggedAt: now.addingTimeInterval(-40 * 86_400), weightKg: 137.5)
  let viewModel = StudentGrowthViewModel(
    plans: StubStudentPlanRepository(
      plans: [CoachStudentFeatureFixtures.studentID: CoachStudentFeatureFixtures.plan()]
    ),
    trainingLogs: StubTrainingLogRepository(logs: [recent, old]),
    now: { now }
  )

  await viewModel.loadIfNeeded(studentID: CoachStudentFeatureFixtures.studentID)

  #expect(viewModel.state == .loaded)
  // Default window 近 4 周 hides the 40-day-old point.
  #expect(viewModel.visiblePoints.map(\.id) == [recent.id])

  viewModel.selectedWindow = .threeMonths
  #expect(viewModel.visiblePoints.map(\.id) == [old.id, recent.id])

  viewModel.selectedWindow = .all
  #expect(viewModel.visiblePoints.map(\.id) == [old.id, recent.id])

  viewModel.selectedFamily = .bench
  #expect(viewModel.visiblePoints.isEmpty)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func growthLoadFailureSetsRetryableFailedState() async {
  let viewModel = StudentGrowthViewModel(
    plans: FailingStudentPlanRepository(),
    trainingLogs: StubTrainingLogRepository(logs: [])
  )

  await viewModel.load(studentID: CoachStudentFeatureFixtures.studentID)

  #expect(viewModel.state == .failed("成长曲线加载失败，请稍后重试"))
  #expect(viewModel.visiblePoints.isEmpty)
}

private func growthLog(
  loggedAt: Date,
  weightKg: Decimal = 142.5,
  rpe: Decimal? = 8.5,
  completed: Bool = true,
  planExerciseID: UUID = CoachStudentFeatureFixtures.planExerciseID
) -> StudentSetLog {
  StudentSetLog(
    id: UUID(),
    studentID: CoachStudentFeatureFixtures.studentID,
    planExerciseID: planExerciseID,
    setIndex: 0,
    loggedAt: loggedAt,
    weightKg: weightKg,
    reps: 5,
    rpe: rpe,
    completed: completed
  )
}

private actor FailingStudentPlanRepository: StudentPlanRepository {
  func fetchCurrentPlan(studentID: UUID) async throws -> StudentPlanView? {
    throw CoachFeatureTestError()
  }

  func fetchDay(studentID: UUID, date: Date) async throws -> StudentPlanDay? {
    throw CoachFeatureTestError()
  }

  func fetchCycleDays(studentID: UUID) async throws -> [StudentPlanDay] {
    throw CoachFeatureTestError()
  }
}
