import Testing

@testable import CoachKit

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func draftTrainingPlanMapsToDomainPlan() throws {
  let draft = PlanningFixtures.draft()

  let plan = try toDomain(draft)

  #expect(plan.id == draft.id)
  #expect(plan.traineeID == PlanningFixtures.activeStudentID)
  #expect(plan.source == .coach)
  #expect(plan.status == .draft)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func draftDaysMapToDomainDays() throws {
  let draft = PlanningFixtures.draft()

  let days = try toDomainDays(draft)

  #expect(days.count == 1)
  #expect(days[0].planID == draft.id)
  #expect(days[0].dayOfWeek == 1)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func draftExercisesMapToDomainExercises() throws {
  let draft = PlanningFixtures.draft()

  let exercises = try toDomainExercises(draft)

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
