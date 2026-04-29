import CoreModels
import Testing

@testable import CoachKit

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func bootstrapLoadsStudentsAndCatalog() async throws {
  let viewModel = try PlanningFixtures.viewModel()

  await viewModel.bootstrap()

  #expect(viewModel.availableStudents.count == 4)
  #expect(viewModel.mainLiftCatalog[.squat]?.count == 3)
  #expect(viewModel.mainLiftCatalog[.bench]?.count == 2)
  #expect(viewModel.mainLiftCatalog[.deadlift]?.count == 2)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func navigationMovesForwardAndBackWithoutDroppingFields() async throws {
  let viewModel = try PlanningFixtures.viewModel()
  await viewModel.bootstrap()

  viewModel.selectStudent(PlanningFixtures.students()[1])
  try await viewModel.goNext()
  viewModel.selectDuration(4)
  try await viewModel.goNext()
  viewModel.sbdFrequency = SBDFrequency(squat: 1, bench: 1, deadlift: 1)
  viewModel.toggleAssignment(dayOfWeek: 1, liftFamily: .squat)
  viewModel.toggleAssignment(dayOfWeek: 3, liftFamily: .bench)
  viewModel.toggleAssignment(dayOfWeek: 5, liftFamily: .deadlift)
  try await viewModel.goNext()

  #expect(viewModel.currentStep == .selectMainLifts)
  viewModel.goBack()
  #expect(viewModel.currentStep == .assignFrequency)
  #expect(viewModel.sbdFrequency.totalSessions == 3)
  #expect(viewModel.dayAssignments[1]?.contains(.squat) == true)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func evaluationStudentCannotSelectFourWeeks() async throws {
  let viewModel = try PlanningFixtures.viewModel()
  await viewModel.bootstrap()

  viewModel.selectStudent(PlanningFixtures.students()[0])
  try await viewModel.goNext()
  viewModel.selectDuration(4)

  #expect(throws: PlanningValidationError.evaluationStudentRequiresOneWeek) {
    try viewModel.validateCurrentStep()
  }
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func assignmentValidationRequiresFrequencyToMatchAssignedLifts() async throws {
  let viewModel = try PlanningFixtures.viewModel()
  await viewModel.bootstrap()

  viewModel.selectStudent(PlanningFixtures.students()[1])
  viewModel.selectDuration(4)
  viewModel.path = [.selectDuration, .assignFrequency]
  viewModel.sbdFrequency = SBDFrequency(squat: 2, bench: 1, deadlift: 1)
  viewModel.toggleAssignment(dayOfWeek: 1, liftFamily: .squat)
  viewModel.toggleAssignment(dayOfWeek: 3, liftFamily: .bench)

  #expect(throws: PlanningValidationError.invalidFrequency) {
    try viewModel.validateCurrentStep()
  }
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func finishWritesDraftAndMarksFlowFinished() async throws {
  let viewModel = try await PlanningFixtures.configuredViewModelForStep3()
  viewModel.selectedVariants[DayLiftKey(dayOfWeek: 1, liftFamily: .squat)] =
    PlanningFixtures.squatID
  viewModel.selectedVariants[DayLiftKey(dayOfWeek: 3, liftFamily: .bench)] =
    PlanningFixtures.benchID
  viewModel.selectedVariants[DayLiftKey(dayOfWeek: 5, liftFamily: .deadlift)] =
    PlanningFixtures.deadliftID

  try await viewModel.finish()

  #expect(viewModel.didFinish)
  #expect(viewModel.draftPlan?.draftDays.count == 3)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func bootstrapRestoresSavedDraftStepAndAssignments() async throws {
  let store = try PlanningFixtures.store()
  try store.saveDraft(PlanningFixtures.draft())
  let viewModel = PlanningViewModel(
    repository: PlanningFixtures.repository(),
    draftStore: store
  )

  await viewModel.bootstrap()

  #expect(viewModel.currentStep == .selectMainLifts)
  #expect(viewModel.selectedStudent?.id == PlanningFixtures.activeStudentID)
  #expect(viewModel.dayAssignments[1]?.contains(.squat) == true)
  #expect(
    viewModel.selectedVariants[DayLiftKey(dayOfWeek: 1, liftFamily: .squat)]
      == PlanningFixtures.squatID)
}
