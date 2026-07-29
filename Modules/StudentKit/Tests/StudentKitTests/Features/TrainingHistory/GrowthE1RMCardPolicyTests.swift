import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import StudentKit

@Test func growthE1RMCardPolicyCoversTheFullWindowAndFamilyCountMatrix() {
  let counts = [0, 1, 2, 3]

  for totalCount in counts {
    for windowCount in counts {
      let expected: GrowthE1RMCardState
      switch totalCount {
      case 0:
        expected = .zero
      case 1, 2:
        expected = .formingProgress
      default:
        expected =
          windowCount >= GrowthHistoryStats.trendUnlockThreshold
          ? .chart : .formingWindowSparse
      }

      #expect(
        GrowthE1RMCardPolicy.state(
          windowDataPointCount: windowCount,
          familyTotalDataPointCount: totalCount,
          windowMainLinePointCount: windowCount,
          windowMainLineValueRangeKg: 1
        ) == expected,
        "window=\(windowCount), total=\(totalCount)"
      )
    }
  }
}

@Test func growthDailyPointIdentityCollapsesMultipleRecordsToTheDaysBest() throws {
  let calendar = growthPolicyCalendar()
  let day = try #require(
    calendar.date(from: DateComponents(year: 2026, month: 7, day: 20, hour: 12))
  )
  let exerciseID = UUID()
  let lower = growthPolicyPoint(exerciseID: exerciseID, date: day, e1RMKg: 145)
  let higher = growthPolicyPoint(
    exerciseID: exerciseID,
    date: day.addingTimeInterval(3_600),
    e1RMKg: 150
  )

  let daily = E1RMSeries.dailyBestEligible(
    points: [lower, higher],
    family: .squat,
    calendar: calendar
  )

  #expect(daily.count == 1)
  #expect(daily.first?.id == higher.id)
}

@Test func growthDailyPointIdentityCountsEqualValuesOnDifferentDays() throws {
  let calendar = growthPolicyCalendar()
  let firstDay = try #require(
    calendar.date(from: DateComponents(year: 2026, month: 7, day: 20, hour: 12))
  )
  let exerciseID = UUID()
  let points = (0..<3).map { offset in
    growthPolicyPoint(
      exerciseID: exerciseID,
      date: firstDay.addingTimeInterval(Double(offset) * 86_400),
      e1RMKg: 150
    )
  }

  let daily = E1RMSeries.dailyBestEligible(
    points: points,
    family: .squat,
    calendar: calendar
  )

  #expect(daily.count == 3)
  #expect(daily.map(\.e1RMKg) == [150, 150, 150])
}

@MainActor
@Test func growthFlatDailySeriesStaysInTheFormingState() async throws {
  let snapshot = try await growthPolicySnapshot(
    values: [
      GrowthPolicyValue(daysAgo: 3, e1RMKg: 150),
      GrowthPolicyValue(daysAgo: 2, e1RMKg: 150),
      GrowthPolicyValue(daysAgo: 1, e1RMKg: 150),
    ]
  )

  #expect(snapshot.eligibleDataPointCount == 3)
  #expect(snapshot.windowDataPointCount == 3)
  #expect(snapshot.samples.map(\.valueKg) == [150, 150, 150])
  #expect(snapshot.cardState == .formingWindowSparse)
}

@MainActor
@Test func growthVaryingDailySeriesDrawsTheChart() async throws {
  let snapshot = try await growthPolicySnapshot(
    values: [
      GrowthPolicyValue(daysAgo: 3, e1RMKg: 150),
      GrowthPolicyValue(daysAgo: 2, e1RMKg: 145),
      GrowthPolicyValue(daysAgo: 1, e1RMKg: 155),
    ]
  )

  #expect(snapshot.eligibleDataPointCount == 3)
  #expect(snapshot.windowDataPointCount == 3)
  #expect(snapshot.samples.map(\.valueKg) == [150, 145, 155])
  #expect(snapshot.cardState == .chart)
}

@MainActor
@Test func growthLowConfidencePointCannotUnlockAFlatTrustedMainLine() async throws {
  let snapshot = try await growthPolicySnapshot(
    values: [
      GrowthPolicyValue(daysAgo: 3, e1RMKg: 150),
      GrowthPolicyValue(daysAgo: 2, e1RMKg: 190, confidence: .low),
      GrowthPolicyValue(daysAgo: 1, e1RMKg: 150),
    ]
  )

  #expect(snapshot.eligibleDataPointCount == 3)
  #expect(snapshot.windowDataPointCount == 3)
  #expect(snapshot.samples.map(\.valueKg) == [150, 150])
  #expect(snapshot.rawEligiblePoints.map(\.e1RMKg) == [190])
  #expect(snapshot.currentKg == 150)
  #expect(snapshot.cardState == .formingWindowSparse)
}

@MainActor
@Test func growthLowConfidenceOnlyDaysNeverUnlockTheMainLine() async throws {
  let snapshot = try await growthPolicySnapshot(
    values: [
      GrowthPolicyValue(daysAgo: 3, e1RMKg: 150, confidence: .low),
      GrowthPolicyValue(daysAgo: 2, e1RMKg: 170, confidence: .low),
      GrowthPolicyValue(daysAgo: 1, e1RMKg: 190, confidence: .low),
    ]
  )

  #expect(snapshot.eligibleDataPointCount == 3)
  #expect(snapshot.windowDataPointCount == 3)
  #expect(snapshot.samples.isEmpty)
  #expect(snapshot.rawEligiblePoints.map(\.e1RMKg) == [150, 170, 190])
  #expect(snapshot.currentKg == nil)
  #expect(snapshot.cardState == .formingWindowSparse)
}

@MainActor
@Test func growthChartPointAndDateAxisIgnoreAnOlderHeadlineCandidate() async throws {
  // The out-of-window 200 must still sit inside the LAST sample's 28-day
  // rolling window, or it can never win the headline and the test passes
  // even against the old shared headline/gold-point implementation.
  let snapshot = try await growthPolicySnapshot(
    range: .ninetyDays,
    values: [
      GrowthPolicyValue(daysAgo: 100, e1RMKg: 200),
      GrowthPolicyValue(daysAgo: 89, e1RMKg: 150),
      GrowthPolicyValue(daysAgo: 85, e1RMKg: 145),
      GrowthPolicyValue(daysAgo: 80, e1RMKg: 155),
    ]
  )
  let axis = GrowthChartDateAxis(snapshot: snapshot)
  let expectedCurrentDate = growthPolicyNow.addingTimeInterval(-80 * 86_400)
  let outOfWindowDate = growthPolicyNow.addingTimeInterval(-100 * 86_400)

  #expect(snapshot.currentKg == 200)
  #expect(snapshot.chartCurrentPoint?.e1RMKg == 155)
  #expect(snapshot.chartCurrentPoint?.computedAt == expectedCurrentDate)
  #expect(axis.currentPointDate == expectedCurrentDate)
  #expect(axis.startDate > outOfWindowDate)
  #expect(axis.endDate == expectedCurrentDate)
  #expect(snapshot.cardState == .chart)
}

@MainActor
@Test func growthWindowSwitchesAllThreeFamiliesThroughOneSharedPolicy() async throws {
  let now = Date(timeIntervalSince1970: 1_774_742_400)
  let plan = StudentDemoSeed.makePlanView(today: now)
  let exercises = plan.days.flatMap(\.exercises)
  let offsets = [-120, -80, -50, -10]
  let points = try MainLiftExerciseFamilyResolver.dashboardFamilies.flatMap { family in
    let exerciseID = try #require(
      exercises.first(where: { $0.exercise.mainLiftFamily == family })?.exercise.id
    )
    return offsets.enumerated().map { index, dayOffset in
      growthPolicyPoint(
        exerciseID: exerciseID,
        date: now.addingTimeInterval(Double(dayOffset) * 86_400),
        e1RMKg: Double(100 + growthFamilyIndex(family) * 50 + index * 5)
      )
    }
  }
  let viewModel = GrowthCurveViewModel(
    plans: InMemoryStudentPlanRepository(
      store: TestStudentPlanStore(seed: [StudentDemoSeed.studentID: plan])
    ),
    e1rm: InMemoryE1RMRepository(seedPoints: points),
    now: { now }
  )

  await viewModel.load(studentID: StudentDemoSeed.studentID)

  for family in MainLiftExerciseFamilyResolver.dashboardFamilies {
    expectWindowTransitions(viewModel: viewModel, family: family, now: now)
  }
}

@MainActor
@Test func growthDemoSeedNeverSelectsAFlatChartAcrossThreeFamiliesAndRanges() async {
  let now = Date()
  let plan = StudentDemoSeed.makePlanView(today: now)
  let viewModel = GrowthCurveViewModel(
    plans: InMemoryStudentPlanRepository(
      store: TestStudentPlanStore(seed: [StudentDemoSeed.studentID: plan])
    ),
    e1rm: InMemoryE1RMRepository(
      seedPoints: StudentDemoSeed.makeE1RMHistory(studentID: StudentDemoSeed.studentID)
    ),
    now: { now }
  )

  await viewModel.load(studentID: StudentDemoSeed.studentID)

  for family in MainLiftExerciseFamilyResolver.dashboardFamilies {
    for range in GrowthTimeRange.allCases {
      let snapshot = GrowthScreenPresentation.snapshot(
        from: viewModel,
        family: family,
        range: range,
        now: now
      )
      if snapshot.cardState == .chart {
        #expect(Set(snapshot.samples.map(\.valueKg)).count > 1)
      }
    }
  }
}

@MainActor
private func expectWindowTransitions(
  viewModel: GrowthCurveViewModel,
  family: LiftFamily,
  now: Date
) {
  let thirtyDays = GrowthScreenPresentation.snapshot(
    from: viewModel,
    family: family,
    range: .thirtyDays,
    now: now
  )
  let ninetyDays = GrowthScreenPresentation.snapshot(
    from: viewModel,
    family: family,
    range: .ninetyDays,
    now: now
  )
  let all = GrowthScreenPresentation.snapshot(
    from: viewModel,
    family: family,
    range: .all,
    now: now
  )

  #expect(thirtyDays.windowDataPointCount == 1)
  #expect(thirtyDays.cardState == .formingWindowSparse)
  #expect(ninetyDays.windowDataPointCount == 3)
  #expect(ninetyDays.cardState == .chart)
  #expect(all.windowDataPointCount == 4)
  #expect(all.cardState == .chart)
}

private func growthFamilyIndex(_ family: LiftFamily) -> Int {
  switch family {
  case .squat:
    0
  case .bench:
    1
  case .deadlift:
    2
  }
}

private func growthPolicyPoint(
  exerciseID: UUID,
  date: Date,
  e1RMKg: Double,
  confidence: E1RMConfidence = .normal
) -> E1RMHistoryPoint {
  E1RMHistoryPoint(
    id: UUID(),
    studentId: StudentDemoSeed.studentID,
    exerciseId: exerciseID,
    setLogId: UUID(),
    computedAt: date,
    e1RMKg: e1RMKg,
    sourceWeightKg: e1RMKg,
    sourceReps: 1,
    sourceRPE: 8,
    confidence: confidence
  )
}

@MainActor
private func growthPolicySnapshot(
  range: GrowthTimeRange = .thirtyDays,
  values: [GrowthPolicyValue]
) async throws -> GrowthCurveSnapshot {
  let now = growthPolicyNow
  let plan = StudentDemoSeed.makePlanView(today: now)
  let exerciseID = try #require(
    plan.days
      .flatMap(\.exercises)
      .first(where: { $0.exercise.mainLiftFamily == .squat })?
      .exercise.id
  )
  let points = values.map { value in
    growthPolicyPoint(
      exerciseID: exerciseID,
      date: now.addingTimeInterval(Double(-value.daysAgo) * 86_400),
      e1RMKg: value.e1RMKg,
      confidence: value.confidence
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
  return GrowthScreenPresentation.snapshot(
    from: viewModel,
    family: .squat,
    range: range,
    now: now
  )
}

private struct GrowthPolicyValue {
  let daysAgo: Int
  let e1RMKg: Double
  var confidence: E1RMConfidence = .normal
}

private let growthPolicyNow = Date(timeIntervalSince1970: 1_774_742_400)

private func growthPolicyCalendar() -> Calendar {
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone
  return calendar
}
