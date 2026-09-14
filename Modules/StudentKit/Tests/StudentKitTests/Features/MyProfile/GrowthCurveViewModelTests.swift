import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import StudentKit

@MainActor
private func makeViewModel(
  pointsDaysAgo: [Double],
  lowConfidenceImportedDaysAgo: Set<Double> = [],
  now: Date = Date(timeIntervalSince1970: 1_768_262_400)
) async -> GrowthCurveViewModel {
  let studentID = StudentDemoSeed.studentID
  let plan = StudentDemoSeed.makePlanView()
  let squatID = plan.days[0].exercises[0].exercise.id

  let seed = pointsDaysAgo.enumerated().map { offset, daysAgo in
    E1RMHistoryPoint(
      id: UUID(), studentId: studentID, exerciseId: squatID, setLogId: UUID(),
      computedAt: now.addingTimeInterval(-daysAgo * 86_400),
      e1RMKg: 120 + Double(offset), sourceWeightKg: 100, sourceReps: 5, sourceRPE: 8,
      confidence: lowConfidenceImportedDaysAgo.contains(daysAgo) ? .low : .normal,
      origin: lowConfidenceImportedDaysAgo.contains(daysAgo) ? .imported : .logged
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
@Test func defaultWindowExpandsToAllWhenHistoryPredatesFourWeeks() async {
  let viewModel = await makeViewModel(pointsDaysAgo: [60, 35, 20, 5, 1])
  #expect(viewModel.selectedFamily == .squat)
  #expect(viewModel.selectedWindow == .all)
  #expect(viewModel.visiblePoints.count == 6)  // Five records + tail continuation.
}

@MainActor
@Test func defaultWindowExpandsForOlderLowConfidenceImportedScatter() async {
  let viewModel = await makeViewModel(
    pointsDaysAgo: [35, 5],
    lowConfidenceImportedDaysAgo: [35]
  )
  #expect(viewModel.selectedWindow == .all)
  #expect(viewModel.visibleRawEligiblePoints.contains { $0.confidence == .low })
}

@MainActor
@Test func defaultWindowStaysAtFourWeeksWithoutEarlierHistory() async {
  let viewModel = await makeViewModel(pointsDaysAgo: [20, 5, 1])
  #expect(viewModel.selectedWindow == .fourWeeks)
  #expect(viewModel.visiblePoints.count == 4)  // Three records + tail continuation.
}

@MainActor
@Test func windowSwitchingWidensTheRange() async {
  let viewModel = await makeViewModel(pointsDaysAgo: [120, 60, 20, 1])

  viewModel.selectedWindow = .threeMonths
  // The 120-day record is carried to the window start, then 60/20/1-day
  // records and the tail continuation remain visible.
  #expect(viewModel.visiblePoints.count == 5)

  viewModel.selectedWindow = .all
  #expect(viewModel.visiblePoints.count == 5)  // Four records + tail continuation.
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
@Test func visibleCurveCarriesTheLatestRecordToToday() async throws {
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

@MainActor
@Test func selectedSampleResolvesToWinningRawPoint() async throws {
  let studentID = StudentDemoSeed.studentID
  let plan = StudentDemoSeed.makePlanView()
  let squatID = try #require(plan.mainLiftIDForGrowthTests(for: .squat))
  let now = Date(timeIntervalSince1970: 1_768_262_400)
  let winner = growthPoint(
    studentID: studentID, exerciseID: squatID, daysAgo: 10, e1RM: 150, now: now)
  let latest = growthPoint(
    studentID: studentID, exerciseID: squatID, daysAgo: 1, e1RM: 145, now: now)
  let viewModel = GrowthCurveViewModel(
    plans: InMemoryStudentPlanRepository(store: TestStudentPlanStore(seed: [studentID: plan])),
    e1rm: InMemoryE1RMRepository(seedPoints: [winner, latest]),
    now: { now }
  )

  await viewModel.load(studentID: studentID)

  let latestSample = try #require(viewModel.visibleSmoothedSamples.last)
  #expect(latestSample.sampleID != winner.id)
  #expect(latestSample.sampleID != latest.id)
  #expect(latestSample.winnerPointID == winner.id)
  #expect(viewModel.winnerPoint(forSampleID: latestSample.sampleID)?.id == winner.id)
}

@MainActor
@Test func lowConfidencePointStaysInRawLayerOnly() async throws {
  let studentID = StudentDemoSeed.studentID
  let plan = StudentDemoSeed.makePlanView()
  let squatID = try #require(plan.mainLiftIDForGrowthTests(for: .squat))
  let now = Date(timeIntervalSince1970: 1_768_262_400)
  let trusted = growthPoint(
    studentID: studentID, exerciseID: squatID, daysAgo: 10, e1RM: 150, now: now)
  let quarantined = E1RMHistoryPoint(
    id: UUID(),
    studentId: studentID,
    exerciseId: squatID,
    setLogId: UUID(),
    computedAt: now.addingTimeInterval(-86_400),
    e1RMKg: 190,
    sourceWeightKg: 170,
    sourceReps: 3,
    sourceRPE: 8,
    confidence: .low,
    origin: .imported
  )
  let viewModel = GrowthCurveViewModel(
    plans: InMemoryStudentPlanRepository(store: TestStudentPlanStore(seed: [studentID: plan])),
    e1rm: InMemoryE1RMRepository(seedPoints: [trusted, quarantined]),
    now: { now }
  )

  await viewModel.load(studentID: studentID)

  #expect(viewModel.visibleSmoothedSamples.map(\.winnerPointID) == [trusted.id, trusted.id])
  #expect(viewModel.visibleRawEligiblePoints.map(\.id) == [quarantined.id])
}

@MainActor
@Test func windowWithoutANewRecordCarriesTheEstablishedValueAndStaysNonempty() async throws {
  let studentID = StudentDemoSeed.studentID
  let plan = StudentDemoSeed.makePlanView()
  let squatID = try #require(plan.mainLiftIDForGrowthTests(for: .squat))
  let now = Date(timeIntervalSince1970: 1_768_262_400)
  let oldRecord = growthPoint(
    studentID: studentID, exerciseID: squatID, daysAgo: 60, e1RM: 150, now: now)
  let recentTraining = growthPoint(
    studentID: studentID, exerciseID: squatID, daysAgo: 5, e1RM: 145, now: now)
  let viewModel = GrowthCurveViewModel(
    plans: InMemoryStudentPlanRepository(store: TestStudentPlanStore(seed: [studentID: plan])),
    e1rm: InMemoryE1RMRepository(seedPoints: [oldRecord, recentTraining]),
    now: { now }
  )

  await viewModel.load(studentID: studentID)
  viewModel.selectedWindow = .fourWeeks

  #expect(viewModel.visibleSmoothedSamples.count == 2)
  #expect(viewModel.visibleSmoothedSamples.allSatisfy { $0.valueKg == 150 })
  #expect(viewModel.visibleSmoothedSamples.allSatisfy { $0.winnerPointID == oldRecord.id })
  #expect(viewModel.visiblePoints.isEmpty == false)
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

@MainActor
@Test func dailyNodeDetailUsesThatDaysWinnerRatherThanTheHeadline() async throws {
  let studentID = StudentDemoSeed.studentID
  let plan = StudentDemoSeed.makePlanView()
  let squatID = try #require(plan.mainLiftIDForGrowthTests(for: .squat))
  let now = Date(timeIntervalSince1970: 1_768_262_400)
  let record = growthPoint(
    studentID: studentID, exerciseID: squatID, daysAgo: 15, e1RM: 155, now: now)
  let weaker = growthPoint(
    studentID: studentID, exerciseID: squatID, daysAgo: 8, e1RM: 140, now: now)
  let winner = growthPoint(
    studentID: studentID, exerciseID: squatID, daysAgo: 8, e1RM: 150, now: now)
  let latest = growthPoint(
    studentID: studentID, exerciseID: squatID, daysAgo: 1, e1RM: 150, now: now)
  let viewModel = GrowthCurveViewModel(
    plans: InMemoryStudentPlanRepository(store: TestStudentPlanStore(seed: [studentID: plan])),
    e1rm: InMemoryE1RMRepository(seedPoints: [record, weaker, winner, latest]),
    now: { now }
  )
  await viewModel.load(studentID: studentID)
  #expect(
    viewModel.visibleDailyBestSamples.map(\.winnerPointID) == [record.id, winner.id, latest.id])
  let detail = try #require(viewModel.detail(forPointID: winner.id, logs: [], days: plan.days))
  #expect(detail.id == winner.id)
  #expect(detail.date == winner.computedAt)
  #expect(detail.point.e1RMKg == 150)
  #expect(viewModel.headlinePoint(for: .squat)?.e1RMKg == 155)
}
