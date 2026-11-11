import CoreModels
import DesignSystem
import SwiftUI
import Testing
import ViewInspector

@testable import StudentKit

@MainActor
struct AllDayDirectEditingTests {
  @Test func keypadLeavesInlineFieldsReachable() async throws {
    let plan = StudentAddedTestPlan.unsettledDemo()
    let model = TodayWorkoutViewModel(
      plans: InMemoryStudentPlanRepository(
        store: TestStudentPlanStore(seed: [StudentDemoSeed.studentID: plan])),
      logs: InMemoryStudentTrainingLogRepository())
    await model.load(dayID: plan.days[0].id, studentID: StudentDemoSeed.studentID)
    let draft = try #require(model.currentDrafts?.first)
    let keypad = WorkoutKeypadSession()
    keypad.openAllDay(draft: draft, viewModel: model, field: .weight)
    let scrims = try WorkoutKeypadOverlay(session: keypad).inspect().findAll(ViewType.Button.self) {
      (try? $0.accessibilityIdentifier()) == "workout.keypad.dismiss"
    }
    #expect(scrims.isEmpty)
    keypad.openAllDay(draft: draft, viewModel: model, field: .rpe)
    #expect(keypad.current?.field == .rpe)
    keypad.openAllDay(draft: draft, viewModel: model, field: .rir)
    #expect(keypad.current?.field == .rir)
    keypad.openAllDay(draft: draft, viewModel: model, field: .weight)
    #expect(keypad.effortField(for: draft.id) == .rir)
    keypad.openAllDay(draft: draft, viewModel: model, field: .rpe)
    #expect(keypad.effortField(for: draft.id) == .rpe)
  }

  @Test func restingRowHasDirectEffortEntry() throws {
    let day = StudentAddedTestPlan.unsettledDemo().days[0]
    let draft = try #require(TodayWorkoutViewModel.makeDrafts(for: day, existingLogs: []).first)
    let row = AllDaySetRow(draft: draft, viewModel: nil, editable: true, onVideo: {})
    let button = try row.inspect().find(
      viewWithAccessibilityIdentifier: "allDay.effort.\(draft.id)"
    ).button()
    #expect(!button.isDisabled())
  }
}

@MainActor
@Test func effortComparisonOnlyShowsAConcreteDifferentPrescription() throws {
  struct Case {
    let target: PrescribedIntensity?
    let rpe: Decimal?
    let rir: Int?
    let original: String?
  }
  let cases: [Case] = [
    .init(target: nil, rpe: 9, rir: nil, original: nil),
    .init(target: .rpe(8), rpe: 8, rir: nil, original: nil),
    .init(target: .rpe(8), rpe: 9, rir: nil, original: "RPE 8"),
    .init(target: .rir(2), rpe: nil, rir: 2, original: nil),
    .init(target: .rir(2), rpe: nil, rir: 1, original: "RIR 2"),
    .init(target: .rpeRange(7, 8), rpe: 8, rir: nil, original: nil),
    .init(target: .rpeRange(7, 8), rpe: 9, rir: nil, original: "RPE 7–8"),
  ]
  for item in cases {
    let original = item.original
    var draft = try #require(
      AllDaySummaryTests.rows(AllDaySummaryTests.sets(1, intensity: item.target)).first)
    draft.actualRPE = item.rpe
    draft.actualRIR = item.rir
    let row = AllDaySetRow(draft: draft, viewModel: nil, editable: true, onVideo: {})
    let originals = try row.inspect().findAll(ViewType.Text.self).filter {
      try $0.string().hasPrefix(StudentStrings.replacing(.allDayOriginal, values: [""]))
    }
    #expect(originals.count == (original == nil ? 0 : 1))
    if let original, let text = originals.first {
      #expect(try text.string() == StudentStrings.replacing(.allDayOriginal, values: [original]))
      #expect(try text.attributes().font() == .MeetPR.body(size: MeetPRFontMetrics.size10))
    }
  }
}
