import CoreModels
import Foundation
import Testing

@testable import CoachKit

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func assemblerMaterializesEveryWeekFromTheW1Draft() {
  // PlanningFixtures.draft(): 4-week plan, 1 training day, 1 main lift.
  let draft = PlanningFixtures.draft()
  let exerciseDraftID = PlanningFixtures.uuid(50)
  let weekOneSpec = DraftSetSpec(
    setCount: 3, targetReps: 5, intensityMode: .weight, targetValue: 100)

  let assembled = PlanPublishAssembler.assemble(
    draft: draft,
    w1Specs: [exerciseDraftID: weekOneSpec],
    rules: [],
    kind: .adaptation
  )

  // kind flows through (an adaptation week must not publish as regular).
  #expect(assembled.plan.kind == .adaptation)
  #expect(assembled.plan.planWeeks == 4)

  // One day per week, weekNumber 1…4, dayOfWeek preserved.
  #expect(assembled.days.count == 4)
  #expect(Set(assembled.days.map(\.weekNumber)) == [1, 2, 3, 4])
  #expect(assembled.days.allSatisfy { $0.dayOfWeek == 1 })
  #expect(assembled.days.allSatisfy { $0.planID == assembled.plan.id })

  // One exercise per week, each under its own day.
  #expect(assembled.exercises.count == 4)
  #expect(Set(assembled.exercises.map(\.planDayID)).count == 4)

  // 3 sets × 4 weeks; with no rules every week keeps the W1 load.
  #expect(assembled.sets.count == 12)
  #expect(assembled.sets.allSatisfy { $0.targetValue == 100 })
  // Sets reference real per-week exercise ids.
  let exerciseIDs = Set(assembled.exercises.map(\.id))
  #expect(assembled.sets.allSatisfy { exerciseIDs.contains($0.planExerciseID) })
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func assemblerAppliesWeeklyRuleWhileSetsStayUnderPerWeekExercise() {
  // The keystone mapping risk: a rule keyed on the W1 draft-exercise id must
  // bump W2+ loads, while the emitted sets attach to each week's fresh
  // exercise id (Codex review).
  let draft = PlanningFixtures.draft()
  let exerciseDraftID = PlanningFixtures.uuid(50)
  let weekOneSpec = DraftSetSpec(
    setCount: 1, targetReps: 5, intensityMode: .weight, targetValue: 100)
  let plusFive = DraftProgressionRule(
    ruleType: .weightInc,
    incrementValue: 5,
    exerciseIDs: [exerciseDraftID],
    appliedWeeks: [2, 3, 4],
    displayOrder: 0
  )

  let assembled = PlanPublishAssembler.assemble(
    draft: draft,
    w1Specs: [exerciseDraftID: weekOneSpec],
    rules: [plusFive],
    kind: .regular
  )

  let exerciseByID = Dictionary(
    uniqueKeysWithValues: assembled.exercises.map { ($0.id, $0) })
  let dayByID = Dictionary(uniqueKeysWithValues: assembled.days.map { ($0.id, $0) })
  // weekNumber → the single set's load that week.
  var loadByWeek: [Int: Decimal] = [:]
  for set in assembled.sets {
    guard let exercise = exerciseByID[set.planExerciseID],
      let day = dayByID[exercise.planDayID]
    else { continue }
    loadByWeek[day.weekNumber] = set.targetValue
  }
  #expect(loadByWeek == [1: 100, 2: 105, 3: 110, 4: 115])
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func assemblerSkipsSetsForExercisesWithoutAW1Spec() {
  let draft = PlanningFixtures.draft()

  let assembled = PlanPublishAssembler.assemble(
    draft: draft,
    w1Specs: [:],
    rules: [],
    kind: .regular
  )

  // Structure still materializes per week; only sets are withheld until the
  // coach fills the spec (the publish gate blocks this case anyway).
  #expect(assembled.days.count == 4)
  #expect(assembled.exercises.count == 4)
  #expect(assembled.sets.isEmpty)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func assemblerPublishesPerSetTargetsForSameExercise() {
  let spec = DraftSetSpec(
    setCount: 5,
    targetReps: 5,
    intensityMode: .weight,
    targetValue: 210,
    perSetTargets: [
      DraftSetTarget(targetReps: 5, intensityMode: .weight, targetValue: 210),
      DraftSetTarget(targetReps: 5, intensityMode: .weight, targetValue: 175),
      DraftSetTarget(targetReps: 5, intensityMode: .weight, targetValue: 175),
      DraftSetTarget(targetReps: 5, intensityMode: .weight, targetValue: 175),
      DraftSetTarget(targetReps: 5, intensityMode: .weight, targetValue: 175),
    ]
  )

  let assembled = PlanPublishAssembler.assemble(
    draft: PlanningFixtures.draft(),
    w1Specs: [PlanningFixtures.uuid(50): spec],
    rules: [],
    kind: .regular
  )

  let weekOneSets = sets(inWeek: 1, assembled: assembled)
  #expect(weekOneSets.map(\.targetValue) == [210, 175, 175, 175, 175])
  #expect(weekOneSets.map(\.targetReps) == [5, 5, 5, 5, 5])
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func assemblerPublishesRestSecondsUsingPerSetSingleThenAutoPriority() {
  let perSetThenSingle = assembledRestSeconds(
    for: DraftSetSpec(
      setCount: 2,
      targetReps: 5,
      intensityMode: .rpe,
      targetValue: 9,
      restSeconds: 180,
      restSecondsPerSet: [90]
    )
  )
  let single = assembledRestSeconds(
    for: DraftSetSpec(
      setCount: 1,
      targetReps: 5,
      intensityMode: .rpe,
      targetValue: 9,
      restSeconds: 165
    )
  )
  let automatic = assembledRestSeconds(
    for: DraftSetSpec(setCount: 1, targetReps: 5, intensityMode: .rpe, targetValue: 9)
  )

  #expect(perSetThenSingle == [90, 180])
  #expect(single.first == 165)
  #expect(automatic.first == 240)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
private func assembledRestSeconds(for spec: DraftSetSpec) -> [Int?] {
  let assembled = PlanPublishAssembler.assemble(
    draft: PlanningFixtures.draft(),
    w1Specs: [PlanningFixtures.uuid(50): spec],
    rules: [],
    kind: .regular
  )
  let exerciseByID = Dictionary(uniqueKeysWithValues: assembled.exercises.map { ($0.id, $0) })
  let dayByID = Dictionary(uniqueKeysWithValues: assembled.days.map { ($0.id, $0) })
  return sets(inWeek: 1, assembled: assembled, exerciseByID: exerciseByID, dayByID: dayByID)
    .map(\.restSeconds)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
private func sets(
  inWeek week: Int,
  assembled: PlanPublishAssembler.Assembled,
  exerciseByID: [UUID: PlanExercise]? = nil,
  dayByID: [UUID: PlanDay]? = nil
) -> [PlanSet] {
  let exerciseByID =
    exerciseByID ?? Dictionary(uniqueKeysWithValues: assembled.exercises.map { ($0.id, $0) })
  let dayByID = dayByID ?? Dictionary(uniqueKeysWithValues: assembled.days.map { ($0.id, $0) })
  return assembled.sets
    .filter { set in
      guard
        let exercise = exerciseByID[set.planExerciseID],
        let day = dayByID[exercise.planDayID]
      else { return false }
      return day.weekNumber == week
    }
    .sorted { $0.setNumber < $1.setNumber }
}
