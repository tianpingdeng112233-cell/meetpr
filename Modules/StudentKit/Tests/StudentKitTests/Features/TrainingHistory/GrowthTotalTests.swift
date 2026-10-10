import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import StudentKit

@Test func totalStartsWhenAllLiftsExistAndCarriesDailyMainLineForward() {
  let squat = totalFixture(.squat, values: [(1, 150), (3, 160), (4, 145)], current: 160)
  let bench = totalFixture(.bench, values: [(2, 100), (4, 105)], current: 105)
  let deadlift = totalFixture(.deadlift, values: [(3, 200)], current: 200)
  #expect(GrowthTotalPresentation.make(snapshots: [squat, bench], range: .all).samples.isEmpty)
  let total = GrowthTotalPresentation.make(snapshots: [squat, bench, deadlift], range: .all)
  #expect(total.samples.map(\.valueKg) == [460, 450])
  #expect(total.samples.map(\.date) == [totalDate(3), totalDate(4)])
  #expect(total.currentKg == 465)
  #expect(total.deltaKg == -10)
  #expect(total.missing.isEmpty)
  #expect(total.state == .sparse)
}

private func totalDate(_ day: Int) -> Date {
  Date(timeIntervalSince1970: 1_780_272_000 + Double(day) * 86_400)
}

@MainActor
@Test func totalUsesEveryDailyMainLineUpdateFromRecordedSetsAndIgnoresLowConfidence() async {
  let studentID = StudentDemoSeed.studentID
  let repository = InMemoryE1RMRepository()
  let plan = StudentDemoSeed.makePlanView()
  let records: [TotalRecordingFixture] = [
    .init(family: .squat, day: 1, weight: 150, confidence: .normal),
    .init(family: .bench, day: 2, weight: 100, confidence: .normal),
    .init(family: .deadlift, day: 3, weight: 200, confidence: .normal),
    .init(family: .squat, day: 4, weight: 160, confidence: .normal),
    .init(family: .squat, day: 5, weight: 145, confidence: .normal),
    .init(family: .bench, day: 5, weight: 105, confidence: .normal),
    .init(family: .squat, day: 6, weight: 900, confidence: .low),
    .init(family: .deadlift, day: 7, weight: 210, confidence: .normal),
  ]
  for record in records {
    let date = totalDate(record.day)
    let exerciseID =
      plan.days.flatMap(\.exercises)
      .first { $0.exercise.mainLiftFamily == record.family }?.exercise.id ?? UUID()
    let log = StudentSetLog(
      id: UUID(), studentID: studentID, planExerciseID: UUID(), setIndex: 0,
      loggedAt: date, weightKg: Decimal(record.weight), reps: 1, rpe: 10, completed: true)
    _ = await E1RMRecorder(e1rm: repository, now: { date }).record(
      .init(
        studentID: log.studentID, exerciseID: exerciseID, family: record.family,
        setLogID: log.id, weightKg: log.weightKg, reps: log.reps, rpe: log.rpe,
        completed: log.completed, failed: false, confidenceOverride: record.confidence))
  }
  let model = GrowthCurveViewModel(
    plans: InMemoryStudentPlanRepository(store: TestStudentPlanStore(seed: [studentID: plan])),
    e1rm: repository, now: { totalDate(8) })
  await model.load(studentID: studentID)
  let snapshots = MainLiftExerciseFamilyResolver.dashboardFamilies.map {
    GrowthScreenPresentation.snapshot(from: model, family: $0, range: .all)
  }
  let total = GrowthTotalPresentation.make(snapshots: snapshots, range: .all, now: totalDate(8))
  #expect(total.samples.map(\.valueKg) == [450, 460, 450, 460])
  #expect(total.samples.map(\.date) == [totalDate(3), totalDate(4), totalDate(5), totalDate(7)])
  #expect(total.currentKg == 475)
  #expect(
    total.currentKg
      == GrowthComparisonPresentation.make(
        snapshots: snapshots, onboarding: nil
      ).estimatedTotalKg)
  #expect(total.state == .chart)
  let old = GrowthTotalPresentation.make(
    snapshots: snapshots, range: .thirtyDays, now: totalDate(90))
  #expect(old.samples.isEmpty)
  #expect(old.currentKg == 475)
  #expect(old.state == .sparse)
}

private func totalFixture(
  _ family: LiftFamily, values: [(Int, Double)], current: Double
) -> GrowthCurveSnapshot {
  let samples = values.map { day, value in
    E1RMSeries.Sample(
      sampleID: UUID(), date: totalDate(day), valueKg: value,
      winnerPointID: UUID(), winnerOrigin: .logged, winnerConfidence: .normal)
  }
  return GrowthCurveSnapshot(
    family: family, samples: samples, rawEligiblePoints: [],
    windowDataPointCount: samples.count, eligibleDataPointCount: samples.count,
    currentKg: current, deltaKg: nil, latestRecordDate: nil, chartCurrentPoint: nil)
}

private struct TotalRecordingFixture {
  let family: LiftFamily
  let day: Int
  let weight: Int
  let confidence: E1RMConfidence
}
