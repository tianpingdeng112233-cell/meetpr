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

  #expect(try inspected.find(text: "评估期内 (1)").string() == "评估期内 (1)")
  #expect(try inspected.find(text: "活跃 (2)").string() == "活跃 (2)")
  #expect(try inspected.find(text: "异常 (1)").string() == "异常 (1)")
  #expect(try inspected.find(text: "评估期 4 天 13 时剩").string() == "评估期 4 天 13 时剩")
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func step1DisablesFourWeekChoiceForEvaluationStudent() async throws {
  let viewModel = try PlanningFixtures.viewModel()
  await viewModel.bootstrap()
  viewModel.selectStudent(PlanningFixtures.students()[0])

  let sut = Step1SelectDurationView(viewModel: viewModel)
  let inspected = try sut.inspect()

  let fourWeekButton = try inspected.find(ViewType.Button.self) { button in
    (try? button.labelView().find(text: "4 周")) != nil
  }

  #expect(fourWeekButton.isDisabled())
  #expect(try inspected.find(text: "评估期内仅 1 周").string() == "评估期内仅 1 周")
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
  #expect(try inspected.find(text: "周一·周三·周五·周六").string() == "周一·周三·周五·周六")
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

  #expect(try inspected.find(text: "周一 — 深蹲").string() == "周一 — 深蹲")
  #expect(try inspected.find(text: "深蹲:").string() == "深蹲:")
  #expect(try inspected.find(text: "比赛式深蹲").string() == "比赛式深蹲")
}
