import CoreModels
import Foundation
import Networking
import Testing

@testable import StudentKit

extension AllDaySummaryTests {
  @MainActor
  @Test(arguments: [SetType.amrap, .warmup])
  func planProjectionPreservesAMRAPAndCountsWarmupNormally(type: SetType) throws {
    let fixture = intensityProjectionFixture()
    let original = try #require(fixture.tree.sets.first)
    var object = try #require(
      JSONSerialization.jsonObject(with: MeetPRCodec.encoder.encode(original)) as? [String: Any])
    object["set_type"] = type.rawValue
    let set = try MeetPRCodec.decoder.decode(
      PlanSet.self, from: JSONSerialization.data(withJSONObject: object))
    let tree = TrainingPlanTree(
      plan: fixture.tree.plan, days: fixture.tree.days,
      exercises: fixture.tree.exercises, sets: [set])
    let plan = StudentPlanProjection.project(
      tree: tree, catalog: [fixture.catalogExercise], weekIndex: 1)
    let day = try #require(plan.days.first)
    let rows = TodayWorkoutViewModel.makeDrafts(for: day, existingLogs: [])
    #expect(
      AllDayExerciseSummary.build(rows: rows).segments.map(\.reps) == [
        type == .amrap ? "1×5+" : "1×5"
      ])
  }
}

@MainActor
@Test(arguments: [PlanLoadMode.fixedWeight, .bodyweight])
func allDayProjectionKeepsExplicitWeightAndEffort(mode: PlanLoadMode) throws {
  let fixture = intensityProjectionFixture()
  let set = intensityProjectionSet(
    exerciseID: fixture.tree.exercises[0].id,
    timestamp: .distantPast, number: 1, legacyMode: .weight, legacyValue: 100,
    loadMode: mode, targetRPE: 7, targetWeight: mode == .bodyweight ? 10 : 100)
  let tree = TrainingPlanTree(
    plan: fixture.tree.plan, days: fixture.tree.days,
    exercises: fixture.tree.exercises, sets: [set])
  let plan = StudentPlanProjection.project(
    tree: tree, catalog: [fixture.catalogExercise], weekIndex: 1)
  let day = try #require(plan.days.first)
  let rows = TodayWorkoutViewModel.makeDrafts(for: day, existingLogs: [])
  let text = AllDayExerciseSummary.build(rows: rows, locale: Locale(identifier: "zh-Hans"))
  #expect(text.segments.map(\.effort) == ["RPE 7"])
  #expect(text.segments.map(\.load) == [mode == .bodyweight ? "自重+10" : "100"])
}
