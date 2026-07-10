import CoreModels
import Foundation
import Testing

@testable import StudentKit

// MARK: - Step gating matrix (spec 032 D11 + wiki required columns)

@Test func step1RequiresAllFiveBasics() {
  var draft = OnboardingDraft()
  #expect(!draft.isStepComplete(1))
  draft.unitPreference = .kg
  draft.gender = .male
  draft.birthDate = "2001-03-15"
  draft.heightCm = 178
  #expect(!draft.isStepComplete(1))
  draft.weightKg = 83
  #expect(draft.isStepComplete(1))
}

@Test func step2BenchGripIsOptional() {
  var draft = OnboardingDraft()
  draft.trainingYears = 0
  draft.squatStance = .highBar
  draft.deadliftStyle = .sumo
  #expect(draft.isStepComplete(2))
  #expect(draft.benchGrip == nil)
}

@Test func step3RequiresAllThreeLifts() {
  var draft = OnboardingDraft()
  draft.squat1RMKg = 180
  draft.bench1RMKg = 120
  #expect(!draft.isStepComplete(3))
  draft.deadlift1RMKg = 220
  #expect(draft.isStepComplete(3))
}

@Test func step4RequiresTwoToSixDaysAndTier() {
  var draft = OnboardingDraft()
  draft.gymTier = .commercial
  draft.trainingDays = [.mon]
  #expect(!draft.isStepComplete(4))
  draft.trainingDays = [.mon, .thu]
  #expect(draft.isStepComplete(4))
  draft.trainingDays = TrainingDay.allCases
  #expect(!draft.isStepComplete(4))  // 7 days exceeds zod max(6)
  draft.trainingDays = []
  draft.trainingDaysUncertain = true
  #expect(draft.isStepComplete(4))
}

@Test func step6IsAlwaysComplete() {
  #expect(OnboardingDraft().isStepComplete(6))
}

@Test func step7CompetitionDateIsConditionallyRequired() {
  var draft = OnboardingDraft()
  #expect(!draft.isStepComplete(7))
  draft.isCompeting = false
  #expect(draft.isStepComplete(7))
  draft.isCompeting = true
  #expect(!draft.isStepComplete(7))
  draft.competitionDate = "2026-07-25"
  #expect(draft.isStepComplete(7))
}

@Test func resumeStepIsFirstIncompleteStep() {
  var draft = OnboardingDraft()
  #expect(draft.resumeStep == 1)
  draft = OnboardingFixtures.completeDraft()
  #expect(draft.resumeStep == 7)
  draft.dailyLifeIntensity = nil
  #expect(draft.resumeStep == 5)
}

// MARK: - Step patches (D5)

@Test func stepPatchOnlyCarriesItsOwnFields() {
  let draft = OnboardingFixtures.completeDraft()
  let patch = draft.patch(forStep: 2)

  #expect(patch.trainingYears == .value(3))
  #expect(patch.squatStance == .value(.lowBar))
  #expect(patch.deadliftStyle == .value(.conventional))
  #expect(patch.benchGrip == .null)  // skipped optional → explicit clear
  // No bleed into other steps:
  #expect(patch.unitPreference == .absent)
  #expect(patch.squat1RMKg == .absent)
  #expect(patch.trainingDays == .absent)
  #expect(patch.isCompeting == .absent)
}

@Test func undersizedTrainingDaysStayAbsent() {
  var draft = OnboardingFixtures.completeDraft()
  draft.trainingDays = [.mon]
  let patch = draft.patch(forStep: 4)
  // zod min(2): never ship a 1-element array (spec 032 risk 3).
  #expect(patch.trainingDays == .absent)
  #expect(patch.gymTier == .value(.commercial))
}

@Test func uncertainTrainingDaysPatchAsNull() {
  var draft = OnboardingFixtures.completeDraft()
  draft.trainingDays = []
  draft.trainingDaysUncertain = true

  let patch = draft.patch(forStep: 4)

  #expect(patch.trainingDays == .null)
  #expect(patch.gymTier == .value(.commercial))
}

@Test func uploadAttachmentIdsAreAbsentInEveryStepPatch() {
  let draft = OnboardingFixtures.completeDraft()
  for step in 1...7 {
    #expect(draft.patch(forStep: step).uploadAttachmentIds == .absent)
  }
  #expect(draft.fullPatch().uploadAttachmentIds == .absent)
}

@Test func emptyTextFieldsPatchAsNull() {
  var draft = OnboardingFixtures.completeDraft()
  draft.injuryNotes = "  "
  draft.noteToCoach = ""
  let patch = draft.patch(forStep: 7)
  #expect(patch.injuryNotes == .null)
  #expect(patch.noteToCoach == .null)
}

@Test func notCompetingClearsCompetitionDate() {
  var draft = OnboardingFixtures.completeDraft()
  draft.isCompeting = false
  draft.competitionDate = "2026-07-25"  // stale leftover
  let patch = draft.patch(forStep: 7)
  #expect(patch.competitionDate == .null)
}

@Test func fullPatchCoversEveryFilledField() {
  var draft = OnboardingFixtures.completeDraft()
  draft.benchGrip = .standard
  draft.muscleGroupsToStrengthen = [.back]
  draft.injuryNotes = "腰部旧伤"
  let patch = draft.fullPatch()

  #expect(patch.unitPreference == .value(.kg))
  #expect(patch.gender == .value(.male))
  #expect(patch.squat1RMKg == .value(180))
  #expect(patch.trainingDays == .value([.mon, .wed, .fri]))
  #expect(patch.benchGrip == .value(.standard))
  #expect(patch.muscleGroupsToStrengthen == .value([.back]))
  #expect(patch.injuryNotes == .value("腰部旧伤"))
  #expect(patch.isCompeting == .value(false))
  #expect(patch.sleepHours == .value(4))
}

// MARK: - Card patches never touch 1RM (spec 032 risk 6)

@Test func cardPatchStepsNeverIncludeOneRM() {
  let draft = OnboardingFixtures.completeDraft()
  let cardKinds: [ProfileCardKind] = [
    .basics, .background, .environment, .recovery, .materials, .competition, .injuries,
  ]
  for kind in cardKinds {
    let patch = draft.patch(forStep: kind.patchStep)
    #expect(!patch.touchesOneRM, "card \(kind) must not carry 1RM fields")
  }
}

// MARK: - D6 merge

@Test func mergePrefersServerWhenLocalIsStale() {
  let server = OnboardingFixtures.serverProfile()
  var local = OnboardingDraft()
  local.gender = .male
  local.savedAt = server.updatedAt.addingTimeInterval(-3_600)  // older than server

  let merged = OnboardingDraft.merged(server: server, local: local)

  #expect(merged.gender == .female)  // server snapshot wins
  #expect(merged.heightCm == 165)
}

@Test func mergeOverlaysNewerLocalNonEmptyFields() {
  let server = OnboardingFixtures.serverProfile()
  var local = OnboardingDraft()
  local.gender = .male
  local.weightKg = 62
  local.savedAt = server.updatedAt.addingTimeInterval(3_600)

  let merged = OnboardingDraft.merged(server: server, local: local)

  #expect(merged.gender == .male)  // local newer → wins
  #expect(merged.weightKg == 62)
  #expect(merged.heightCm == 165)  // unset locally → server kept
  #expect(merged.squatStance == .highBar)
}

@Test func mergeWithoutServerUsesLocalDraft() {
  var local = OnboardingDraft()
  local.gender = .other
  #expect(OnboardingDraft.merged(server: nil, local: local).gender == .other)
  #expect(OnboardingDraft.merged(server: nil, local: nil) == OnboardingDraft())
}

@Test func mergeToleratesSmallClockDriftInFavorOfLocal() {
  // risk 5: 60s tolerance — a local save 30s "before" the server update
  // (drifted clock) still wins.
  let server = OnboardingFixtures.serverProfile()
  var local = OnboardingDraft()
  local.gender = .male
  local.savedAt = server.updatedAt.addingTimeInterval(-30)

  let merged = OnboardingDraft.merged(server: server, local: local)

  #expect(merged.gender == .male)
}

// MARK: - D12 missing_fields → step mapping (all 19 gate fields)

@Test func missingFieldStepMappingCoversAllNineteenGateFields() {
  let expectations: [(String, Int)] = [
    ("unit_preference", 1), ("gender", 1), ("birth_date", 1), ("height_cm", 1),
    ("weight_kg", 1),
    ("training_years", 2), ("squat_stance", 2), ("deadlift_style", 2),
    ("squat_1rm_kg", 3), ("bench_1rm_kg", 3), ("deadlift_1rm_kg", 3),
    ("training_days", 4), ("gym_tier", 4),
    ("daily_life_intensity", 5), ("life_stress", 5), ("recovery_speed", 5),
    ("sleep_hours", 5),
    ("is_competing", 7), ("competition_date", 7),
  ]
  #expect(expectations.count == 19)
  for (field, step) in expectations {
    #expect(OnboardingDraft.step(forMissingField: field) == step, "\(field)")
  }
  #expect(OnboardingDraft.step(forMissingField: "unknown_field") == nil)
}

@Test func earliestStepPicksTheLowestStep() {
  #expect(
    OnboardingDraft.earliestStep(forMissingFields: ["sleep_hours", "gender", "gym_tier"]) == 1)
  #expect(OnboardingDraft.earliestStep(forMissingFields: ["competition_date"]) == 7)
  #expect(OnboardingDraft.earliestStep(forMissingFields: ["mystery"]) == nil)
}
