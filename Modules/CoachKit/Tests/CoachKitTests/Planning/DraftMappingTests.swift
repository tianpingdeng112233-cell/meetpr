import Testing

@testable import CoachKit

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func draftTrainingPlanMapsToDomainPlan() {
  let draft = PlanningFixtures.draft()

  let plan = toDomain(draft)

  #expect(plan.id == draft.id)
  #expect(plan.traineeID == PlanningFixtures.activeStudentID)
  #expect(plan.source == .coach)
  #expect(plan.status == .draft)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func draftDaysMapToDomainDays() {
  let draft = PlanningFixtures.draft()

  let days = toDomainDays(draft)

  #expect(days.count == 1)
  #expect(days[0].planID == draft.id)
  #expect(days[0].dayOfWeek == 1)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func draftExercisesMapToDomainExercises() {
  let draft = PlanningFixtures.draft()

  let exercises = toDomainExercises(draft)

  #expect(exercises.count == 1)
  #expect(exercises[0].exerciseID == PlanningFixtures.squatID)
  #expect(exercises[0].isMainLift)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func domainPlanDaysAndExercisesRebuildDraft() {
  let draft = fromDomain(
    plan: PlanningFixtures.plan(),
    days: PlanningFixtures.planDays(),
    exercises: PlanningFixtures.planExercises(),
    currentStep: .selectMainLifts
  )

  #expect(draft.id == PlanningFixtures.planID)
  #expect(draft.currentStepRawValue == PlanningStep.selectMainLifts.rawValue)
  #expect(draft.draftDays.count == 1)
  #expect(draft.draftDays[0].draftExercises[0].notes == "主项")
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func draftMappingEncodesAndDecodesSetSpec() throws {
  let spec = Spec007Fixtures.setSpec(targetValue: 137.5)

  let decoded = decodeSetSpec(try encodeSetSpec(spec))

  #expect(decoded?.targetValue == 137.5)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func draftMappingDecodeSetSpecReturnsNilForNilData() {
  #expect(decodeSetSpec(nil) == nil)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func draftMappingEncodesRulesEmptyAndNonEmpty() throws {
  let empty = decodeRules(try encodeRules([]))
  let nonEmpty = decodeRules(try encodeRules([Spec007Fixtures.rule(.weightInc)]))

  #expect(empty.isEmpty)
  #expect(nonEmpty.count == 1)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func draftMappingExpandsSetSpecToPlanSets() throws {
  let draft = PlanningFixtures.draft()
  let exercise = try #require(draft.draftDays.first?.draftExercises.first)
  exercise.setsData = try encodeSetSpec(Spec007Fixtures.setSpec(setCount: 4))

  let sets = toDomainSets(draft)

  #expect(sets.count == 4)
  #expect(sets.map(\.setNumber) == [1, 2, 3, 4])
  #expect(sets.allSatisfy { $0.planExerciseID == exercise.id })
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func draftMappingExpandsPerSetTargetsToPlanSets() throws {
  let draft = PlanningFixtures.draft()
  let exercise = try #require(draft.draftDays.first?.draftExercises.first)
  exercise.setsData = try encodeSetSpec(
    DraftSetSpec(
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
    ))

  let sets = toDomainSets(draft)

  #expect(sets.map(\.setNumber) == [1, 2, 3, 4, 5])
  #expect(sets.map(\.targetValue) == [210, 175, 175, 175, 175])
  #expect(sets.map(\.targetReps) == [5, 5, 5, 5, 5])
}
