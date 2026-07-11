import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import StudentKit

@MainActor
private func makeViewModel(
  pointsDaysAgo: [Double],
  now: Date = Date(timeIntervalSince1970: 1_768_262_400)
) async -> GrowthCurveViewModel {
  let studentID = StudentDemoSeed.studentID
  let plan = StudentDemoSeed.makePlanView()
  let squatID = plan.days[0].exercises[0].exercise.id

  let seed = pointsDaysAgo.enumerated().map { offset, daysAgo in
    E1RMHistoryPoint(
      id: UUID(), studentId: studentID, exerciseId: squatID, setLogId: UUID(),
      computedAt: now.addingTimeInterval(-daysAgo * 86_400),
      e1RMKg: 120 + Double(offset), sourceWeightKg: 100, sourceReps: 5, sourceRPE: 8
    )
  }
  let viewModel = GrowthCurveViewModel(
    plans: InMemoryStudentPlanRepository(store: TestStudentPlanStore(seed: [studentID: plan])),
    e1rm: InMemoryE1RMRepository(seedPoints: seed),
    now: { now }
  )
  await viewModel.load(studentID: studentID)
  return viewModel
}

@MainActor
@Test func defaultWindowShowsOnlyLastFourWeeks() async {
  let viewModel = await makeViewModel(pointsDaysAgo: [60, 35, 20, 5, 1])
  #expect(viewModel.selectedFamily == .squat)
  #expect(viewModel.selectedWindow == .fourWeeks)
  #expect(viewModel.visiblePoints.count == 3)  // 20, 5, 1 days ago
}

@MainActor
@Test func windowSwitchingWidensTheRange() async {
  let viewModel = await makeViewModel(pointsDaysAgo: [120, 60, 20, 1])

  viewModel.selectedWindow = .threeMonths
  #expect(viewModel.visiblePoints.count == 3)  // 60, 20, 1

  viewModel.selectedWindow = .all
  #expect(viewModel.visiblePoints.count == 4)
}

@MainActor
@Test func familyWithNoMainLiftHistoryIsEmpty() async {
  let viewModel = await makeViewModel(pointsDaysAgo: [5, 1])
  viewModel.selectedFamily = .bench
  #expect(viewModel.visiblePoints.isEmpty)
}

@MainActor
@Test func pointsStayAscendingForTheChart() async {
  let viewModel = await makeViewModel(pointsDaysAgo: [3, 25, 10])
  let dates = viewModel.visiblePoints.map(\.computedAt)
  #expect(dates == dates.sorted())
}

@MainActor
@Test func visibleCurveUsesRollingWindowMaximum() async throws {
  let studentID = StudentDemoSeed.studentID
  let plan = StudentDemoSeed.makePlanView()
  let squatID = try #require(plan.mainLiftIDForGrowthTests(for: .squat))
  let now = Date(timeIntervalSince1970: 1_768_262_400)
  let seed = [
    growthPoint(studentID: studentID, exerciseID: squatID, daysAgo: 10, e1RM: 150, now: now),
    growthPoint(studentID: studentID, exerciseID: squatID, daysAgo: 1, e1RM: 145, now: now),
  ]
  let viewModel = GrowthCurveViewModel(
    plans: InMemoryStudentPlanRepository(store: TestStudentPlanStore(seed: [studentID: plan])),
    e1rm: InMemoryE1RMRepository(seedPoints: seed),
    now: { now }
  )

  await viewModel.load(studentID: studentID)

  #expect(viewModel.visiblePoints.map(\.e1RMKg) == [150, 150])
}

private func growthPoint(
  studentID: UUID,
  exerciseID: UUID,
  daysAgo: Int,
  e1RM: Double,
  now: Date
) -> E1RMHistoryPoint {
  E1RMHistoryPoint(
    id: UUID(),
    studentId: studentID,
    exerciseId: exerciseID,
    setLogId: UUID(),
    computedAt: now.addingTimeInterval(TimeInterval(-daysAgo) * 86_400),
    e1RMKg: e1RM,
    sourceWeightKg: e1RM * 0.85,
    sourceReps: 5,
    sourceRPE: 8
  )
}

extension StudentPlanView {
  fileprivate func mainLiftIDForGrowthTests(for family: LiftFamily) -> UUID? {
    days.flatMap(\.exercises).first {
      $0.exercise.exerciseType == .mainLift && $0.exercise.mainLiftFamily == family
    }?.exercise.id
  }
}
