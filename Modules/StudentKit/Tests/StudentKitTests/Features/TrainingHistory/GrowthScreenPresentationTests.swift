import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import StudentKit

@Test func growthComparisonUsesOnboardingBaselinesAndCapsBars() {
  let profile = StudentDemoSeed.makeOnboardingProfile(studentID: StudentDemoSeed.studentID)
  let snapshots = [
    snapshot(.squat, current: 187.5),
    snapshot(.bench, current: 118.6),
    snapshot(.deadlift, current: 225),
  ]

  let presentation = GrowthComparisonPresentation.make(
    snapshots: snapshots,
    onboarding: profile
  )

  #expect(presentation.estimatedTotalKg == 531.1)
  #expect(presentation.trainingTotalKg == 520)
  #expect(presentation.rows[0].progress == 1)
  #expect(presentation.rows[0].hasExceededTrainingBaseline)
  #expect(presentation.rows[1].progress < 1)
  #expect(presentation.rows[2].percentage == 102)
}

@Test func growthHistoryStatsExcludeIncompleteAndAssumedLogs() {
  let calendar = growthCalendar()
  let logs = [
    growthLog(day: 1, weight: 100, reps: 5, calendar: calendar),
    growthLog(day: 1, weight: 80, reps: 5, calendar: calendar),
    growthLog(day: 3, weight: 120, reps: 3, calendar: calendar),
    growthLog(day: 8, weight: 200, reps: 1, calendar: calendar),
    growthLog(day: 9, weight: 999, reps: 9, completed: false, calendar: calendar),
    growthLog(day: 10, weight: 999, reps: 9, assumed: true, calendar: calendar),
  ]

  let stats = GrowthScreenPresentation.historyStats(logs: logs, calendar: calendar)

  #expect(stats.trainingSessionCount == 3)
  #expect(stats.trainingWeekCount == 2)
  #expect(stats.totalVolumeKg == 1_460)
  #expect(stats.unlocksTrends)
}

@Test func growthChartBucketsKeepTheLatestSixWeeks() {
  let calendar = growthCalendar()
  let logs = (0..<8).map { week in
    growthLog(
      day: 1 + week * 7,
      weight: Decimal(100 + week),
      reps: 5,
      calendar: calendar
    )
  }

  let buckets = GrowthScreenPresentation.chartBuckets(
    logs: logs,
    calendar: calendar,
    maximumCount: 6
  )

  #expect(buckets.count == 6)
  #expect(buckets.first?.volumeKg == 510)
  #expect(buckets.last?.volumeKg == 535)
}

@Test func growthTrendUnlockRequiresThreeDistinctTrainingDays() {
  let calendar = growthCalendar()
  let logs = [
    growthLog(day: 1, weight: 100, reps: 5, calendar: calendar),
    growthLog(day: 1, weight: 110, reps: 3, calendar: calendar),
    growthLog(day: 2, weight: 120, reps: 3, calendar: calendar),
  ]

  let stats = GrowthScreenPresentation.historyStats(logs: logs, calendar: calendar)

  #expect(stats.trainingSessionCount == 2)
  #expect(!stats.unlocksTrends)
}

@Test func growthTimeRangesMapWithoutChangingViewModelContract() {
  #expect(GrowthTimeRange(timeWindow: .fourWeeks) == .thirtyDays)
  #expect(GrowthTimeRange(timeWindow: .threeMonths) == .ninetyDays)
  #expect(GrowthTimeRange(timeWindow: .all) == .all)
  #expect(GrowthTimeRange.thirtyDays.timeWindow == .fourWeeks)
  #expect(GrowthTimeRange.ninetyDays.timeWindow == .threeMonths)
  #expect(GrowthTimeRange.all.timeWindow == .all)
  #expect(GrowthTimeRange.allCases == [.thirtyDays, .ninetyDays, .all])
}

@MainActor
@Test func growthSnapshotKeepsHeadlineButAnchorsChartToWindowMainLine() async {
  let studentID = StudentDemoSeed.studentID
  let plan = StudentDemoSeed.makePlanView()
  let exerciseID = plan.days[0].exercises[0].exercise.id
  let now = Date(timeIntervalSince1970: 1_774_742_400)
  let record = growthSnapshotPoint(
    studentID: studentID,
    exerciseID: exerciseID,
    date: now.addingTimeInterval(-20 * 86_400),
    e1RMKg: 150
  )
  let laterNonRecord = growthSnapshotPoint(
    studentID: studentID,
    exerciseID: exerciseID,
    date: now.addingTimeInterval(-5 * 86_400),
    e1RMKg: 145
  )
  let importedLow = growthSnapshotPoint(
    studentID: studentID,
    exerciseID: exerciseID,
    date: now.addingTimeInterval(-10 * 86_400),
    e1RMKg: 190,
    confidence: .low,
    origin: .imported
  )
  let viewModel = GrowthCurveViewModel(
    plans: InMemoryStudentPlanRepository(store: TestStudentPlanStore(seed: [studentID: plan])),
    e1rm: InMemoryE1RMRepository(seedPoints: [record, laterNonRecord, importedLow]),
    now: { now }
  )

  await viewModel.load(studentID: studentID)
  let snapshot = GrowthScreenPresentation.snapshot(
    from: viewModel,
    family: .squat,
    range: .ninetyDays,
    now: now
  )

  #expect(snapshot.samples.map(\.valueKg) == [150, 145])
  #expect(snapshot.samples.last?.date == laterNonRecord.computedAt)
  #expect(snapshot.currentKg == 150)
  #expect(snapshot.latestRecordDate == record.computedAt)
  #expect(snapshot.chartCurrentPoint?.id == laterNonRecord.id)
  #expect(snapshot.rawEligiblePoints.map(\.id) == [importedLow.id])
}

@MainActor
@Test func growthTrendUnlocksAtExactlyThreeRecordsForItsExerciseFamily() async throws {
  let now = Date(timeIntervalSince1970: 1_774_742_400)
  let plan = StudentDemoSeed.makePlanView(today: now)
  let squatExerciseID = try #require(
    plan.days
      .flatMap(\.exercises)
      .first(where: { $0.exercise.mainLiftFamily == .squat })?
      .exercise.id
  )
  let points = (1...3).map { index in
    growthSnapshotPoint(
      studentID: StudentDemoSeed.studentID,
      exerciseID: squatExerciseID,
      date: now.addingTimeInterval(Double(index - 4) * 86_400),
      e1RMKg: Double(140 + index)
    )
  }
  let viewModel = GrowthCurveViewModel(
    plans: InMemoryStudentPlanRepository(
      store: TestStudentPlanStore(seed: [StudentDemoSeed.studentID: plan])
    ),
    e1rm: InMemoryE1RMRepository(seedPoints: points),
    now: { now }
  )

  await viewModel.load(studentID: StudentDemoSeed.studentID)
  let snapshot = GrowthScreenPresentation.snapshot(
    from: viewModel,
    family: .squat,
    range: .ninetyDays,
    now: now
  )

  #expect(snapshot.eligibleDataPointCount == GrowthHistoryStats.trendUnlockThreshold)
  #expect(snapshot.windowDataPointCount == GrowthHistoryStats.trendUnlockThreshold)
  #expect(snapshot.cardState == .chart)
}

@MainActor
@Test func growthTrendRecordCountsStayIsolatedBetweenExerciseFamilies() async throws {
  let now = Date(timeIntervalSince1970: 1_774_742_400)
  let plan = StudentDemoSeed.makePlanView(today: now)
  let exercises = plan.days.flatMap(\.exercises)
  let squatExerciseID = try #require(
    exercises.first(where: { $0.exercise.mainLiftFamily == .squat })?.exercise.id
  )
  let benchExerciseID = try #require(
    exercises.first(where: { $0.exercise.mainLiftFamily == .bench })?.exercise.id
  )
  let squatPoints = (1...3).map { index in
    growthSnapshotPoint(
      studentID: StudentDemoSeed.studentID,
      exerciseID: squatExerciseID,
      date: now.addingTimeInterval(Double(index - 4) * 86_400),
      e1RMKg: Double(140 + index)
    )
  }
  let benchPoint = growthSnapshotPoint(
    studentID: StudentDemoSeed.studentID,
    exerciseID: benchExerciseID,
    date: now.addingTimeInterval(-86_400),
    e1RMKg: 100
  )
  let viewModel = GrowthCurveViewModel(
    plans: InMemoryStudentPlanRepository(
      store: TestStudentPlanStore(seed: [StudentDemoSeed.studentID: plan])
    ),
    e1rm: InMemoryE1RMRepository(seedPoints: squatPoints + [benchPoint]),
    now: { now }
  )

  await viewModel.load(studentID: StudentDemoSeed.studentID)
  let squat = GrowthScreenPresentation.snapshot(
    from: viewModel,
    family: .squat,
    range: .ninetyDays,
    now: now
  )
  let bench = GrowthScreenPresentation.snapshot(
    from: viewModel,
    family: .bench,
    range: .ninetyDays,
    now: now
  )

  #expect(squat.eligibleDataPointCount == 3)
  #expect(squat.cardState == .chart)
  #expect(bench.eligibleDataPointCount == 1)
  #expect(bench.cardState == .formingProgress)
}

private func snapshot(_ family: LiftFamily, current: Double) -> GrowthCurveSnapshot {
  GrowthCurveSnapshot(
    family: family,
    samples: [],
    rawEligiblePoints: [],
    windowDataPointCount: 0,
    eligibleDataPointCount: 0,
    currentKg: current,
    deltaKg: nil,
    latestRecordDate: nil,
    chartCurrentPoint: nil
  )
}

private func growthSnapshotPoint(
  studentID: UUID,
  exerciseID: UUID,
  date: Date,
  e1RMKg: Double,
  confidence: E1RMConfidence = .normal,
  origin: E1RMPointOrigin = .logged
) -> E1RMHistoryPoint {
  E1RMHistoryPoint(
    id: UUID(),
    studentId: studentID,
    exerciseId: exerciseID,
    setLogId: UUID(),
    computedAt: date,
    e1RMKg: e1RMKg,
    sourceWeightKg: e1RMKg,
    sourceReps: 1,
    sourceRPE: 8,
    confidence: confidence,
    origin: origin
  )
}

private func growthLog(
  day: Int,
  weight: Decimal,
  reps: Int,
  completed: Bool = true,
  assumed: Bool = false,
  calendar: Calendar
) -> StudentSetLog {
  var components = DateComponents()
  components.calendar = calendar
  components.timeZone = calendar.timeZone
  components.year = 2026
  components.month = 6
  components.day = day
  components.hour = 12
  return StudentSetLog(
    id: UUID(),
    studentID: StudentDemoSeed.studentID,
    planExerciseID: UUID(),
    setIndex: 0,
    loggedAt: calendar.date(from: components) ?? Date(timeIntervalSince1970: 0),
    weightKg: weight,
    reps: reps,
    rpe: 8,
    completed: completed,
    assumed: assumed
  )
}

private func growthCalendar() -> Calendar {
  var calendar = Calendar(identifier: .gregorian)
  calendar.locale = Locale(identifier: "en_US_POSIX")
  calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone
  calendar.firstWeekday = 2
  calendar.minimumDaysInFirstWeek = 4
  return calendar
}
