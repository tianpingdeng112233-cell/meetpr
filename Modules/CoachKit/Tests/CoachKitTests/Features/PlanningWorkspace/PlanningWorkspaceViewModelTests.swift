import CoreModels
import Foundation
import Testing

@testable import CoachKit

@available(iOS 17.0, macOS 14.0, *)
private enum PlanningWorkspaceTestFixtures {
  static let now = Date(timeIntervalSince1970: 1_797_552_000)
  static let draftStudentID = uuid(1)
  static let endingStudentID = uuid(2)
  static let noPlanStudentID = uuid(3)
  static let recentStudentID = uuid(4)

  static var calendar: Calendar {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone
    return calendar
  }

  static func students() -> [CoachStudentSummary] {
    [
      student(id: draftStudentID, name: "王五"),
      student(id: endingStudentID, name: "张三"),
      student(id: noPlanStudentID, name: "赵六"),
      student(id: recentStudentID, name: "李四"),
    ]
  }

  static func student(id: UUID, name: String) -> CoachStudentSummary {
    CoachStudentSummary(id: id, displayName: name, status: .active)
  }

  static func plan(startOffset: Int, weeks: Int, kind: PlanKind = .regular) -> StudentPlanView {
    let startDate = now.addingTimeInterval(Double(startOffset) * 86_400)
    return StudentPlanView(
      cycleID: uuid(UInt8(40 + weeks)),
      weekIndex: 1,
      startDate: startDate,
      planKind: kind,
      days: (0..<(weeks * 7)).map { offset in
        StudentPlanDay(
          id: uuid(UInt8(60 + offset)),
          date: startDate.addingTimeInterval(Double(offset) * 86_400),
          exercises: []
        )
      }
    )
  }

  static func draft() -> DraftTrainingPlan {
    DraftTrainingPlan(
      traineeID: draftStudentID,
      name: "王五 4 周计划",
      startDate: now,
      endDate: now.addingTimeInterval(27 * 86_400),
      planWeeks: 4,
      currentStepRawValue: PlanningStep.selectAccessories.rawValue,
      lastSavedAt: now.addingTimeInterval(-600)
    )
  }

  static func profile(studentID: UUID = endingStudentID) -> OnboardingProfile {
    OnboardingProfile(
      userId: studentID,
      squat1RMKg: 180,
      bench1RMKg: 120,
      deadlift1RMKg: 220,
      trainingDays: [.mon, .wed, .fri],
      gymTier: .commercial,
      createdAt: now,
      updatedAt: now
    )
  }

  static func uuid(_ byte: UInt8) -> UUID {
    UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, byte))
  }
}

@available(iOS 17.0, macOS 14.0, *)
@Test func planNeedReasonDetectsCycleEndingThisWeek() {
  let plan = PlanningWorkspaceTestFixtures.plan(startOffset: -7, weeks: 2)
  let reason = PlanningWorkspaceSummary.planNeedReason(
    plan: plan,
    cycleDays: plan.days,
    now: PlanningWorkspaceTestFixtures.now,
    calendar: PlanningWorkspaceTestFixtures.calendar
  )

  #expect(reason == .endsThisWeek)
}

@available(iOS 17.0, macOS 14.0, *)
@Test func planNeedReasonDetectsEndedCycle() {
  let plan = PlanningWorkspaceTestFixtures.plan(startOffset: -14, weeks: 1)
  let reason = PlanningWorkspaceSummary.planNeedReason(
    plan: plan,
    cycleDays: plan.days,
    now: PlanningWorkspaceTestFixtures.now,
    calendar: PlanningWorkspaceTestFixtures.calendar
  )

  #expect(reason == .ended)
}

@available(iOS 17.0, macOS 14.0, *)
@Test func planNeedReasonSkipsRunningCycle() {
  let plan = PlanningWorkspaceTestFixtures.plan(startOffset: -2, weeks: 4)
  let reason = PlanningWorkspaceSummary.planNeedReason(
    plan: plan,
    cycleDays: plan.days,
    now: PlanningWorkspaceTestFixtures.now,
    calendar: PlanningWorkspaceTestFixtures.calendar
  )

  #expect(reason == nil)
}

@available(iOS 17.0, macOS 14.0, *)
@Test func planNeedReasonDetectsMissingCurrentPlan() {
  let reason = PlanningWorkspaceSummary.planNeedReason(
    plan: nil,
    cycleDays: [],
    now: PlanningWorkspaceTestFixtures.now,
    calendar: PlanningWorkspaceTestFixtures.calendar
  )

  #expect(reason == .noCurrentPlan)
}

@available(iOS 17.0, macOS 14.0, *)
@Test func draftProgressSummaryMapsStepNameAndWeeks() {
  let summary = PlanningWorkspaceSummary.draftProgressSummary(
    name: "张三 4 周计划",
    currentStepRawValue: PlanningStep.configureRules.rawValue,
    planWeeks: 4
  )
  let stepTitle = PlanningWorkspaceStrings.text("coach.workspace.step.configureRules")

  #expect(
    summary
      == CoachLocalization.localized(
        "coach.workspace.draftSummary \("张三 4 周计划") \(stepTitle) \(4)"
      ))
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func workspaceViewModelLoadsDraftNeedsAndRecentSections() async throws {
  let store = try DraftStore.inMemory()
  try store.saveDraft(PlanningWorkspaceTestFixtures.draft())
  let endingPlan = PlanningWorkspaceTestFixtures.plan(startOffset: -7, weeks: 2)
  let recentPlan = PlanningWorkspaceTestFixtures.plan(startOffset: -2, weeks: 4)
  let viewModel = PlanningWorkspaceViewModel(
    repository: StubCoachPlanRepository(students: PlanningWorkspaceTestFixtures.students()),
    studentPlans: StubStudentPlanRepository(plans: [
      PlanningWorkspaceTestFixtures.endingStudentID: endingPlan,
      PlanningWorkspaceTestFixtures.recentStudentID: recentPlan,
    ]),
    draftStore: store,
    profiles: InMemoryCoachStudentProfileReader(
      profiles: [PlanningWorkspaceTestFixtures.profile()]
    ),
    now: { PlanningWorkspaceTestFixtures.now },
    calendar: PlanningWorkspaceTestFixtures.calendar
  )

  await viewModel.refresh()

  #expect(viewModel.draftRows.map(\.id) == [PlanningWorkspaceTestFixtures.draftStudentID])
  #expect(
    viewModel.needsPlanningRows.map(\.id) == [
      PlanningWorkspaceTestFixtures.endingStudentID,
      PlanningWorkspaceTestFixtures.noPlanStudentID,
    ])
  #expect(viewModel.needsPlanningRows.first?.reason == .endsThisWeek)
  #expect(
    viewModel.needsPlanningRows.first?.profile?.userId
      == PlanningWorkspaceTestFixtures.endingStudentID)
  #expect(
    viewModel.recentPublishedRows.map(\.id) == [
      PlanningWorkspaceTestFixtures.recentStudentID,
      PlanningWorkspaceTestFixtures.endingStudentID,
    ])
  let regularKind = PlanningWorkspaceStrings.text("coach.workspace.kind.regular")
  #expect(
    viewModel.recentPublishedRows.first?.summary
      == CoachLocalization.localized("coach.workspace.publishedSummary \(regularKind) \(4)"))
  #expect(viewModel.hasWorkspaceContent)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func workspaceViewModelEmptyCoachFallsBackToNoSections() async throws {
  let viewModel = PlanningWorkspaceViewModel(
    repository: StubCoachPlanRepository(students: []),
    studentPlans: StubStudentPlanRepository(plans: [:]),
    draftStore: try DraftStore.inMemory(),
    now: { PlanningWorkspaceTestFixtures.now },
    calendar: PlanningWorkspaceTestFixtures.calendar
  )

  await viewModel.refresh()

  #expect(viewModel.draftRows.isEmpty)
  #expect(viewModel.needsPlanningRows.isEmpty)
  #expect(viewModel.recentPublishedRows.isEmpty)
  #expect(!viewModel.hasWorkspaceContent)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func firstRegularPlanIntentWithNilProfileResumesExistingDraft() async throws {
  let store = try PlanningFixtures.store()
  let draft = PlanningFixtures.draft()
  try store.saveDraft(draft)
  let student = PlanningFixtures.students()[1]
  let viewModel = PlanningViewModel(
    repository: PlanningFixtures.repository(),
    draftStore: store,
    intent: .firstRegularPlan(student, nil)
  )

  await viewModel.bootstrap()

  #expect(viewModel.draftPlan?.id == draft.id)
  #expect(viewModel.planWeeks == draft.planWeeks)
  #expect(viewModel.selectedStudent?.id == student.id)
  #expect(viewModel.currentStep == .selectMainLifts)
}
