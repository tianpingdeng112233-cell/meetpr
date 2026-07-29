import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import StudentKit

@MainActor
@Test(arguments: [0, 1, 2, 3])
func eligibleRecordCountSelectsZeroFormingAndMatureStates(
  recordCount: Int
) async throws {
  let studentID = StudentDemoSeed.studentID
  let plan = StudentDemoSeed.makePlanView()
  let squatID = try #require(formingStateMainLiftID(in: plan, family: .squat))
  let now = try Date("2026-07-28T12:00:00Z", strategy: .iso8601)
  let points = (0..<recordCount).map { index in
    formingStatePoint(
      studentID: studentID,
      exerciseID: squatID,
      e1RM: 170 + Double(index) * 2.5,
      daysAgo: recordCount - index,
      now: now
    )
  }
  let viewModel = formingStateViewModel(
    studentID: studentID,
    plan: plan,
    points: points,
    now: now
  )

  await viewModel.load(studentID: studentID)

  let presentation = try #require(formingStatePresentation(from: viewModel))
  let squat = try #require(presentation.rows.first { $0.family == .squat })
  let expectedState: DashboardE1RMTrendState =
    switch recordCount {
    case 0: .zero
    case 1, 2: .forming
    default: .mature
    }
  #expect(squat.eligibleRecordCount == recordCount)
  #expect(squat.trendState == expectedState)
  #expect(squat.latestDisplayDate == points.last?.computedAt)
}

@MainActor
@Test func formingTrendDateMatchesRecordValueWhenLatestEligibleIsNotARecord() async throws {
  let studentID = StudentDemoSeed.studentID
  let plan = StudentDemoSeed.makePlanView()
  let squatID = try #require(formingStateMainLiftID(in: plan, family: .squat))
  let now = try Date("2026-07-28T12:00:00Z", strategy: .iso8601)
  let record = formingStatePoint(
    studentID: studentID,
    exerciseID: squatID,
    e1RM: 170,
    daysAgo: 2,
    now: now
  )
  let laterNonRecord = formingStatePoint(
    studentID: studentID,
    exerciseID: squatID,
    e1RM: 165,
    daysAgo: 1,
    now: now
  )
  let viewModel = formingStateViewModel(
    studentID: studentID,
    plan: plan,
    points: [record, laterNonRecord],
    now: now
  )

  await viewModel.load(studentID: studentID)

  let presentation = try #require(formingStatePresentation(from: viewModel))
  let squat = try #require(presentation.rows.first { $0.family == .squat })
  #expect(squat.trendState == .forming)
  #expect(squat.latestRecordPoint?.e1RMKg == 170)
  #expect(squat.latestDisplayDate == record.computedAt)
  #expect(squat.latestDisplayDate != laterNonRecord.computedAt)
}

@MainActor
private func formingStateViewModel(
  studentID: UUID,
  plan: StudentPlanView,
  points: [E1RMHistoryPoint],
  now: Date
) -> DashboardE1RMTrendViewModel {
  DashboardE1RMTrendViewModel(
    plans: InMemoryStudentPlanRepository(
      store: TestStudentPlanStore(seed: [studentID: plan])
    ),
    e1rm: InMemoryE1RMRepository(seedPoints: points),
    now: { now }
  )
}

@MainActor
private func formingStatePresentation(
  from viewModel: DashboardE1RMTrendViewModel
) -> DashboardE1RMTrendPresentation? {
  guard case .loaded(let presentation) = viewModel.state else {
    return nil
  }
  return presentation
}

private func formingStateMainLiftID(
  in plan: StudentPlanView,
  family: LiftFamily
) -> UUID? {
  MainLiftExerciseFamilyResolver.exerciseIDsByFamily(
    in: plan,
    onboarding: nil
  )[family]?.first
}

private func formingStatePoint(
  studentID: UUID,
  exerciseID: UUID,
  e1RM: Double,
  daysAgo: Int,
  now: Date
) -> E1RMHistoryPoint {
  E1RMHistoryPoint(
    id: UUID(),
    studentId: studentID,
    exerciseId: exerciseID,
    setLogId: UUID(),
    computedAt: now.addingTimeInterval(Double(-daysAgo) * 86_400),
    e1RMKg: e1RM,
    sourceWeightKg: e1RM * 0.88,
    sourceReps: 5,
    sourceRPE: 8
  )
}
