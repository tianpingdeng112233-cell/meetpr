import CoreModels
import Testing
import ViewInspector

@testable import CoachKit

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func step0RendersThreeStudentSections() async throws {
  let viewModel = try PlanningFixtures.viewModel()
  await viewModel.bootstrap()

  let sut = Step0SelectStudentView(viewModel: viewModel)
  let inspected = try sut.inspect()

  #expect(
    try inspected.find(text: "\(CoachPlanningStrings.inEvaluation) (1)".uppercased()).string()
      == "\(CoachPlanningStrings.inEvaluation) (1)".uppercased())
  #expect(
    try inspected.find(text: "\(CoachPlanningStrings.active) (2)".uppercased()).string()
      == "\(CoachPlanningStrings.active) (2)".uppercased())
  #expect(
    try inspected.find(text: "\(CoachPlanningStrings.abnormal) (1)".uppercased()).string()
      == "\(CoachPlanningStrings.abnormal) (1)".uppercased())
  #expect(
    try inspected.find(text: CoachPlanningStrings.evaluationRemaining(days: 4, hours: 13)).string()
      == CoachPlanningStrings.evaluationRemaining(days: 4, hours: 13))
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func step1ShowsOnlyOneWeekCardForEvaluationStudent() async throws {
  let viewModel = try PlanningFixtures.viewModel()
  await viewModel.bootstrap()
  viewModel.selectStudent(PlanningFixtures.students()[0])

  let sut = Step1SelectDurationView(viewModel: viewModel)
  let inspected = try sut.inspect()

  // Adaptation week (spec 033 §7) is the single-week exception, so the step
  // offers only the 1-week card — no 4-week choice.
  _ = try inspected.find(ViewType.Button.self) { button in
    (try? button.labelView().find(text: CoachPlanningStrings.weekCount(1))) != nil
  }
  #expect(throws: (any Error).self) {
    try inspected.find(ViewType.Button.self) { button in
      (try? button.labelView().find(text: CoachPlanningStrings.weekCount(4))) != nil
    }
  }
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func step1ShowsOnlyFourWeekCardForRegularStudent() async throws {
  let viewModel = try PlanningFixtures.viewModel()
  await viewModel.bootstrap()
  viewModel.selectStudent(PlanningFixtures.students()[1])

  let sut = Step1SelectDurationView(viewModel: viewModel)
  let inspected = try sut.inspect()

  // Regular plans are always a full 4-week block, so the step offers only the
  // 4-week card — the single-week option is gone.
  _ = try inspected.find(ViewType.Button.self) { button in
    (try? button.labelView().find(text: CoachPlanningStrings.weekCount(4))) != nil
  }
  #expect(throws: (any Error).self) {
    try inspected.find(ViewType.Button.self) { button in
      (try? button.labelView().find(text: CoachPlanningStrings.weekCount(1))) != nil
    }
  }
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func step2RendersDisabledTemplateEntrypoints() async throws {
  let viewModel = try PlanningFixtures.viewModel()
  await viewModel.bootstrap()
  viewModel.selectStudent(PlanningFixtures.students()[1])
  viewModel.selectDuration(4)

  let sut = Step2AssignFrequencyView(viewModel: viewModel)
  let inspected = try sut.inspect()

  #expect(
    try inspected.find(text: CoachPlanningStrings.useTemplate).string()
      == CoachPlanningStrings.useTemplate)
  #expect(
    try inspected.find(text: CoachPlanningStrings.copyLastWeek).string()
      == CoachPlanningStrings.copyLastWeek)
  #expect(
    try inspected.find(text: CoachPlanningStrings.trainingDayCount(7, fromProfile: false)).string()
      == CoachPlanningStrings.trainingDayCount(7, fromProfile: false)
  )
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func step3RendersPerDayMainLiftPickers() async throws {
  let viewModel = try PlanningFixtures.viewModel()
  await viewModel.bootstrap()
  viewModel.selectStudent(PlanningFixtures.students()[1])
  viewModel.selectDuration(4)
  viewModel.sbdFrequency = SBDFrequency(squat: 1, bench: 0, deadlift: 0)
  viewModel.toggleAssignment(dayOfWeek: 1, liftFamily: .squat)

  let sut = Step3SelectMainLiftsView(viewModel: viewModel)
  let inspected = try sut.inspect()

  #expect(
    try inspected.find(text: "DAY 1 — \(CoachPlanningStrings.squat)").string()
      == "DAY 1 — \(CoachPlanningStrings.squat)")
  #expect(
    try inspected.find(text: "\(CoachPlanningStrings.squat):").string()
      == "\(CoachPlanningStrings.squat):")
  // Variant picker uses a Button + sheet pattern; the variant list itself is in
  // the sheet (not in the inline view tree). Unselected row shows "请选择".
  #expect(
    try inspected.find(text: CoachPlanningStrings.chooseExercise).string()
      == CoachPlanningStrings.chooseExercise)
}
