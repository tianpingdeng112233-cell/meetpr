import CoreModels
import Testing
import ViewInspector

@testable import CoachKit

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func step0RendersActiveAndAbnormalStudentSections() async throws {
  let viewModel = try PlanningFixtures.viewModel()
  await viewModel.bootstrap()

  let sut = Step0SelectStudentView(viewModel: viewModel)
  let inspected = try sut.inspect()

  #expect(try inspected.find(text: "活跃 (2)").string() == "活跃 (2)")
  #expect(try inspected.find(text: "异常 (1)").string() == "异常 (1)")
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func step1ShowsRegularDurationForLegacyEvaluationStatus() async throws {
  let viewModel = try PlanningFixtures.viewModel()
  await viewModel.bootstrap()
  viewModel.selectStudent(PlanningFixtures.students()[0])

  let sut = Step1SelectDurationView(viewModel: viewModel)
  let inspected = try sut.inspect()

  // A stale legacy status no longer changes the planning surface.
  _ = try inspected.find(ViewType.Button.self) { button in
    (try? button.labelView().find(text: "4 周")) != nil
  }
  #expect(throws: (any Error).self) {
    try inspected.find(ViewType.Button.self) { button in
      (try? button.labelView().find(text: "1 周")) != nil
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
    (try? button.labelView().find(text: "4 周")) != nil
  }
  #expect(throws: (any Error).self) {
    try inspected.find(ViewType.Button.self) { button in
      (try? button.labelView().find(text: "1 周")) != nil
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

  #expect(try inspected.find(text: "使用模板").string() == "使用模板")
  #expect(try inspected.find(text: "复制上周").string() == "复制上周")
  #expect(
    try inspected.find(text: "每周 7 个训练日").string()
      == "每周 7 个训练日"
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

  #expect(try inspected.find(text: "DAY 1 — 深蹲").string() == "DAY 1 — 深蹲")
  #expect(try inspected.find(text: "深蹲:").string() == "深蹲:")
  // Variant picker uses a Button + sheet pattern; the variant list itself is in
  // the sheet (not in the inline view tree). Unselected row shows "请选择".
  #expect(try inspected.find(text: "请选择").string() == "请选择")
}
