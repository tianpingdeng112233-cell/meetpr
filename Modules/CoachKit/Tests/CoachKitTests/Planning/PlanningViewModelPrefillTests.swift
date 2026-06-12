import CoreModels
import Foundation
import Testing

@testable import CoachKit

@available(iOS 17.0, macOS 14.0, *)
private func makeProfile(
  gymTier: GymTier = .homeWithRack,
  equipmentOverrides: [String] = []
) -> OnboardingProfile {
  OnboardingProfile(
    userId: PlanningFixtures.activeStudentID,
    squat1RMKg: 180,
    bench1RMKg: 120,
    deadlift1RMKg: 220,
    trainingDays: [.mon, .wed, .fri, .sat],
    gymTier: gymTier,
    equipmentOverrides: equipmentOverrides,
    createdAt: PlanningFixtures.now,
    updatedAt: PlanningFixtures.now
  )
}

@available(iOS 17.0, macOS 14.0, *)
private func activeStudent() -> CoachStudentSummary {
  PlanningFixtures.students()[1]
}

// MARK: - Pure prefill mapping

@available(iOS 17.0, macOS 14.0, *)
@Test func trainingDayTokensMapToWeekdayInts() {
  #expect(PlanningPrefill.preferredDays(from: [.mon, .wed, .sun]) == [1, 3, 7])
  #expect(PlanningPrefill.preferredDays(from: []) == [])
}

@available(iOS 17.0, macOS 14.0, *)
@Test func oneRMsMapPerFamilyDroppingMissing() {
  let profile = makeProfile()
  let oneRMs = PlanningPrefill.oneRMs(from: profile)
  #expect(oneRMs[.squat] == 180)
  #expect(oneRMs[.bench] == 120)
  #expect(oneRMs[.deadlift] == 220)

  let partial = OnboardingProfile(
    userId: UUID(),
    squat1RMKg: 100,
    createdAt: PlanningFixtures.now,
    updatedAt: PlanningFixtures.now
  )
  let partialOneRMs = PlanningPrefill.oneRMs(from: partial)
  #expect(partialOneRMs[.squat] == 100)
  #expect(partialOneRMs[.bench] == nil)
}

@available(iOS 17.0, macOS 14.0, *)
@Test func equipmentFilterFollowsGymTierTable() {
  // home_with_rack → home preset.
  #expect(
    PlanningPrefill.equipmentFilter(from: makeProfile(gymTier: .homeWithRack))
      == [.barbell, .dumbbell, .bodyweight, .band])
  // commercial / professional → no preset (full catalog).
  #expect(PlanningPrefill.equipmentFilter(from: makeProfile(gymTier: .commercial)) == nil)
  #expect(PlanningPrefill.equipmentFilter(from: makeProfile(gymTier: .professional)) == nil)
  // Override tokens hitting Equipment rawValues merge in; unknown ignored.
  #expect(
    PlanningPrefill.equipmentFilter(
      from: makeProfile(gymTier: .commercial, equipmentOverrides: ["kettlebell", "smith_machine"])
    ) == [.kettlebell])
}

// MARK: - Intent presets

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func adaptationIntentPresetsStudentDurationAndKind() async throws {
  let viewModel = try PlanningViewModel(
    repository: PlanningFixtures.repository(),
    draftStore: PlanningFixtures.store(),
    intent: .adaptationWeek(activeStudent())
  )

  await viewModel.bootstrap()

  #expect(viewModel.selectedStudent?.id == PlanningFixtures.activeStudentID)
  #expect(viewModel.path == [.selectDuration])
  #expect(viewModel.planKind == .adaptation)
  #expect(viewModel.planWeeks == 1)
  viewModel.selectDuration(4)
  #expect(throws: PlanningValidationError.evaluationStudentRequiresOneWeek) {
    try viewModel.validateCurrentStep()
  }
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func adaptationDraftNameUsesAdaptationTemplate() async throws {
  let viewModel = try PlanningViewModel(
    repository: PlanningFixtures.repository(),
    draftStore: PlanningFixtures.store(),
    intent: .adaptationWeek(activeStudent())
  )
  await viewModel.bootstrap()

  viewModel.selectDuration(1)
  try await viewModel.goNext()

  #expect(viewModel.draftPlan?.name == "张三 适应周")
  #expect(viewModel.draftPlan?.planWeeks == 1)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func firstRegularIntentStaysRegularDespiteStaleEvaluationStatus() async throws {
  // The roster snapshot can still say in-evaluation right after the
  // completion chain — the soft recommendation explicitly schedules a
  // regular plan (spec 033 §9).
  let staleStudent = PlanningFixtures.students()[0]
  let viewModel = try PlanningViewModel(
    repository: PlanningFixtures.repository(),
    draftStore: PlanningFixtures.store(),
    intent: .firstRegularPlan(staleStudent, makeProfile())
  )

  await viewModel.bootstrap()

  #expect(viewModel.planKind == .regular)
  viewModel.selectDuration(4)
  #expect(viewModel.isCurrentStepValid)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func blankFlowWithEvaluationStudentForcesAdaptationKind() async throws {
  let viewModel = try PlanningFixtures.viewModel()
  await viewModel.bootstrap()

  viewModel.selectStudent(PlanningFixtures.students()[0])

  #expect(viewModel.planKind == .adaptation)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func intentResumesExistingDraftInsteadOfOverwriting() async throws {
  let store = try PlanningFixtures.store()
  let first = PlanningViewModel(
    repository: PlanningFixtures.repository(),
    draftStore: store,
    intent: .adaptationWeek(activeStudent())
  )
  await first.bootstrap()
  first.selectDuration(1)
  try await first.goNext()
  #expect(first.draftPlan != nil)

  let second = PlanningViewModel(
    repository: PlanningFixtures.repository(),
    draftStore: store,
    intent: .adaptationWeek(activeStudent())
  )
  await second.bootstrap()

  // The saved draft resumes (spec 033 risk 4) — never silently replaced.
  #expect(second.draftPlan != nil)
  #expect(second.planWeeks == 1)
  #expect(second.selectedStudent?.id == PlanningFixtures.activeStudentID)
}

// MARK: - Prefill consumption

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func preferredDaysBecomeTheOnlySlotsLabeledByRank() async throws {
  let viewModel = try PlanningViewModel(
    repository: PlanningFixtures.repository(),
    draftStore: PlanningFixtures.store(),
    intent: .firstRegularPlan(activeStudent(), makeProfile())
  )
  await viewModel.bootstrap()

  // mon/wed/fri/sat preferred → exactly four slots, labeled DAY 1..4
  // (David 2026-06-12: coach no longer picks weekdays).
  #expect(viewModel.assignmentDisplayDays == [1, 3, 5, 6])
  #expect(viewModel.dayLabel(1) == "DAY 1")
  #expect(viewModel.dayLabel(3) == "DAY 2")
  #expect(viewModel.dayLabel(6) == "DAY 4")
  // Marks only — nothing auto-assigned (D8).
  #expect(viewModel.dayAssignments.isEmpty)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func staleAssignmentOutsidePreferredSlotsStaysVisible() async throws {
  let viewModel = try PlanningViewModel(
    repository: PlanningFixtures.repository(),
    draftStore: PlanningFixtures.store(),
    intent: .firstRegularPlan(activeStudent(), makeProfile())
  )
  await viewModel.bootstrap()

  // A draft made before the slot change may hold an assignment on a hidden
  // weekday — it must surface so it can be unassigned, not become ghost data.
  viewModel.toggleAssignment(dayOfWeek: 2, liftFamily: .squat)

  #expect(viewModel.assignmentDisplayDays == [1, 2, 3, 5, 6])
  #expect(viewModel.dayLabel(2) == "DAY 2")
  #expect(viewModel.dayLabel(3) == "DAY 3")
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func blankFlowKeepsAllSevenSlots() async throws {
  let viewModel = try PlanningFixtures.viewModel()
  await viewModel.bootstrap()

  #expect(viewModel.assignmentDisplayDays == [1, 2, 3, 4, 5, 6, 7])
  #expect(viewModel.dayLabel(5) == "DAY 5")
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func prefilledEquipmentSeedsDefaultAccessoryFilters() async throws {
  let viewModel = try PlanningViewModel(
    repository: PlanningFixtures.repository(),
    draftStore: PlanningFixtures.store(),
    intent: .firstRegularPlan(activeStudent(), makeProfile(gymTier: .homeWithRack))
  )
  await viewModel.bootstrap()

  let filters = viewModel.accessoryFilters(for: UUID())
  #expect(filters.equipment == [.barbell, .dumbbell, .bodyweight, .band])

  // An explicit per-day filter still wins.
  let dayID = UUID()
  await viewModel.updateFilters(AccessoryFilters(equipment: [.machine]), for: dayID)
  #expect(viewModel.accessoryFilters(for: dayID).equipment == [.machine])
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func prefilledOneRMFeedsOneRMLookupForMainLifts() async throws {
  let viewModel = try PlanningViewModel(
    repository: PlanningFixtures.repository(),
    draftStore: PlanningFixtures.store(),
    intent: .firstRegularPlan(activeStudent(), makeProfile())
  )
  await viewModel.bootstrap()
  viewModel.selectDuration(4)
  try await viewModel.goNext()
  viewModel.sbdFrequency = SBDFrequency(squat: 1, bench: 0, deadlift: 0)
  viewModel.toggleAssignment(dayOfWeek: 1, liftFamily: .squat)
  try await viewModel.goNext()
  let key = DayLiftKey(dayOfWeek: 1, liftFamily: .squat)
  try viewModel.pickMainLiftVariant(PlanningFixtures.squatID, for: key)
  let draftExercise = try #require(viewModel.mainLiftDraftExercise(for: key))

  #expect(viewModel.oneRM(for: draftExercise) == 180)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func blankFlowOneRMStaysNil() async throws {
  let viewModel = try PlanningFixtures.viewModel()
  await viewModel.bootstrap()
  viewModel.selectStudent(activeStudent())
  viewModel.selectDuration(4)
  try await viewModel.goNext()
  try await viewModel.goNext()
  viewModel.sbdFrequency = SBDFrequency(squat: 1, bench: 0, deadlift: 0)
  viewModel.toggleAssignment(dayOfWeek: 1, liftFamily: .squat)
  try await viewModel.goNext()
  let key = DayLiftKey(dayOfWeek: 1, liftFamily: .squat)
  try viewModel.pickMainLiftVariant(PlanningFixtures.squatID, for: key)
  let draftExercise = try #require(viewModel.mainLiftDraftExercise(for: key))

  #expect(viewModel.oneRM(for: draftExercise) == nil)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func blankFlowLoadsSlotsFromSelectedStudentProfile() async throws {
  // 排新计划 entry: no prefill intent — the slots load when the coach picks
  // the student in Step 0 (David 2026-06-12).
  let viewModel = try PlanningViewModel(
    repository: PlanningFixtures.repository(),
    draftStore: PlanningFixtures.store(),
    intent: .blank,
    profiles: InMemoryCoachStudentProfileReader(profiles: [makeProfile()])
  )
  await viewModel.bootstrap()
  #expect(viewModel.assignmentDisplayDays == [1, 2, 3, 4, 5, 6, 7])

  viewModel.selectStudent(activeStudent())
  await viewModel.loadPreferredTrainingDays(for: activeStudent().id)

  #expect(viewModel.assignmentDisplayDays == [1, 3, 5, 6])
  #expect(viewModel.dayLabel(5) == "DAY 3")
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func adaptationIntentLoadsSlotsOnBootstrap() async throws {
  // .adaptationWeek carries the student but no prefill profile — bootstrap
  // must still resolve the DAY slots.
  let viewModel = try PlanningViewModel(
    repository: PlanningFixtures.repository(),
    draftStore: PlanningFixtures.store(),
    intent: .adaptationWeek(activeStudent()),
    profiles: InMemoryCoachStudentProfileReader(profiles: [makeProfile()])
  )
  await viewModel.bootstrap()

  #expect(viewModel.assignmentDisplayDays == [1, 3, 5, 6])
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func repickingAnotherStudentDropsPreviousStudentSlots() async throws {
  let viewModel = try PlanningViewModel(
    repository: PlanningFixtures.repository(),
    draftStore: PlanningFixtures.store(),
    intent: .blank,
    profiles: InMemoryCoachStudentProfileReader(profiles: [makeProfile()])
  )
  await viewModel.bootstrap()

  viewModel.selectStudent(activeStudent())
  await viewModel.loadPreferredTrainingDays(for: activeStudent().id)
  #expect(viewModel.assignmentDisplayDays == [1, 3, 5, 6])

  // The other student has no profile in the reader → slots reset to the
  // 7-day fallback instead of keeping the first student's days (Codex).
  let other = PlanningFixtures.students()[0]
  viewModel.selectStudent(other)
  await viewModel.loadPreferredTrainingDays(for: other.id)

  #expect(viewModel.assignmentDisplayDays == [1, 2, 3, 4, 5, 6, 7])
}
