import CoreModels
import Foundation

/// Mutable working copy the 7-step wizard binds to (spec 032 §5). Distinct
/// from `OnboardingProfile` (immutable server snapshot): all fields optional
/// or empty, plus resume metadata. Persisted as plain JSON by
/// `LocalOnboardingDraftStore`.
public struct OnboardingDraft: Codable, Equatable, Sendable {
  // Step 1
  public var unitPreference: UnitPreference?
  public var gender: Gender?
  public var birthDate: String?
  public var heightCm: Decimal?
  public var weightKg: Decimal?
  // Step 2
  public var trainingYears: Int?
  public var squatStance: SquatStance?
  public var deadliftStyle: DeadliftStance?
  public var benchGrip: BenchGrip?
  // Step 3
  public var squat1RMKg: Decimal?
  public var bench1RMKg: Decimal?
  public var deadlift1RMKg: Decimal?
  // Step 4
  public var trainingDays: [TrainingDay] = []
  public var trainingDaysUncertain: Bool?
  public var gymTier: GymTier?
  public var equipmentOverrides: [String] = []
  // Step 5
  public var dailyLifeIntensity: Int?
  public var lifeStress: Int?
  public var recoverySpeed: Int?
  public var sleepHours: Int?
  // Step 6 (uploads stay out of the draft — degraded Step 6, spec 032 §8)
  public var muscleGroupsToStrengthen: [MuscleGroup] = []
  // Step 7 — text fields stay non-optional for SwiftUI bindings; empty
  // means "not provided" and patches as JSON null.
  public var injuryNotes: String = ""
  public var injuryAreas: [InjuryArea] = []
  public var isCompeting: Bool?
  public var competitionDate: String?
  public var targetWeightClass: String = ""
  public var noteToCoach: String = ""
  // Resume metadata (D6)
  public var savedAt: Date = .distantPast
  public var furthestStep: Int = 1

  public init() {}
}

// MARK: - Server snapshot ↔ draft (D6 merge)

extension OnboardingDraft {
  public static func from(_ profile: OnboardingProfile) -> OnboardingDraft {
    var draft = OnboardingDraft()
    draft.unitPreference = profile.unitPreference
    draft.gender = profile.gender
    draft.birthDate = profile.birthDate
    draft.heightCm = profile.heightCm
    draft.weightKg = profile.weightKg
    draft.trainingYears = profile.trainingYears
    draft.squatStance = profile.squatStance
    draft.deadliftStyle = profile.deadliftStyle
    draft.benchGrip = profile.benchGrip
    draft.squat1RMKg = profile.squat1RMKg
    draft.bench1RMKg = profile.bench1RMKg
    draft.deadlift1RMKg = profile.deadlift1RMKg
    draft.trainingDays = profile.trainingDays
    draft.trainingDaysUncertain =
      profile.trainingDays.isEmpty && profile.gymTier != nil ? true : nil
    draft.gymTier = profile.gymTier
    draft.equipmentOverrides = profile.equipmentOverrides
    draft.dailyLifeIntensity = profile.dailyLifeIntensity
    draft.lifeStress = profile.lifeStress
    draft.recoverySpeed = profile.recoverySpeed
    draft.sleepHours = profile.sleepHours
    draft.muscleGroupsToStrengthen = profile.muscleGroupsToStrengthen
    draft.injuryNotes = profile.injuryNotes ?? ""
    draft.injuryAreas = profile.injuryAreas
    draft.isCompeting = profile.isCompeting
    draft.competitionDate = profile.competitionDate
    draft.targetWeightClass = profile.targetWeightClass ?? ""
    draft.noteToCoach = profile.noteToCoach ?? ""
    draft.savedAt = profile.updatedAt
    return draft
  }

  /// Server is the base, newer-wins overlay (spec 032 D6): the local draft's
  /// non-empty fields cover the server snapshot when the draft was saved
  /// after the server row was updated. A 60s tolerance favors the local copy
  /// against clock drift (risk 5 — single-device V0.1 semantics).
  public static func merged(
    server: OnboardingProfile?,
    local: OnboardingDraft?
  ) -> OnboardingDraft {
    guard let server else { return local ?? OnboardingDraft() }
    let base = OnboardingDraft.from(server)
    guard let local,
      local.savedAt > server.updatedAt.addingTimeInterval(-60)
    else { return base }
    return base.overlaying(local)
  }

  /// Local non-empty fields win; empty/unset local fields keep the base.
  func overlaying(_ local: OnboardingDraft) -> OnboardingDraft {
    var merged = local
    merged.unitPreference = local.unitPreference ?? unitPreference
    merged.gender = local.gender ?? gender
    merged.birthDate = local.birthDate ?? birthDate
    merged.heightCm = local.heightCm ?? heightCm
    merged.weightKg = local.weightKg ?? weightKg
    merged.trainingYears = local.trainingYears ?? trainingYears
    merged.squatStance = local.squatStance ?? squatStance
    merged.deadliftStyle = local.deadliftStyle ?? deadliftStyle
    merged.benchGrip = local.benchGrip ?? benchGrip
    merged.squat1RMKg = local.squat1RMKg ?? squat1RMKg
    merged.bench1RMKg = local.bench1RMKg ?? bench1RMKg
    merged.deadlift1RMKg = local.deadlift1RMKg ?? deadlift1RMKg
    if local.trainingDaysUncertain == true {
      merged.trainingDays = []
      merged.trainingDaysUncertain = true
    } else if !local.trainingDays.isEmpty {
      merged.trainingDays = local.trainingDays
      merged.trainingDaysUncertain = nil
    } else {
      merged.trainingDays = trainingDays
      merged.trainingDaysUncertain = trainingDaysUncertain
    }
    merged.gymTier = local.gymTier ?? gymTier
    merged.equipmentOverrides =
      local.equipmentOverrides.isEmpty ? equipmentOverrides : local.equipmentOverrides
    merged.dailyLifeIntensity = local.dailyLifeIntensity ?? dailyLifeIntensity
    merged.lifeStress = local.lifeStress ?? lifeStress
    merged.recoverySpeed = local.recoverySpeed ?? recoverySpeed
    merged.sleepHours = local.sleepHours ?? sleepHours
    merged.muscleGroupsToStrengthen =
      local.muscleGroupsToStrengthen.isEmpty
      ? muscleGroupsToStrengthen : local.muscleGroupsToStrengthen
    merged.injuryNotes = local.injuryNotes.isEmpty ? injuryNotes : local.injuryNotes
    merged.injuryAreas = local.injuryAreas.isEmpty ? injuryAreas : local.injuryAreas
    merged.isCompeting = local.isCompeting ?? isCompeting
    merged.competitionDate = local.competitionDate ?? competitionDate
    merged.targetWeightClass =
      local.targetWeightClass.isEmpty ? targetWeightClass : local.targetWeightClass
    merged.noteToCoach = local.noteToCoach.isEmpty ? noteToCoach : local.noteToCoach
    return merged
  }
}

// MARK: - Step gating + resume (D11)

extension OnboardingDraft {
  public static let stepCount = 7

  /// UI required-field gate per step (wiki v2.4 required columns). PUT
  /// itself never requires completeness — this only gates "下一步".
  public func isStepComplete(_ step: Int) -> Bool {
    switch step {
    case 1:
      return unitPreference != nil && gender != nil && birthDate != nil
        && heightCm != nil && weightKg != nil
    case 2:
      return trainingYears != nil && squatStance != nil && deadliftStyle != nil
    case 3:
      return squat1RMKg != nil && bench1RMKg != nil && deadlift1RMKg != nil
    case 4:
      return ((2...6).contains(trainingDays.count) || trainingDaysUncertain == true)
        && gymTier != nil
    case 5:
      return dailyLifeIntensity != nil && lifeStress != nil
        && recoverySpeed != nil && sleepHours != nil
    case 6:
      return true  // uploads degraded + muscle groups optional
    case 7:
      return isCompeting != nil && (isCompeting == false || competitionDate != nil)
    default:
      return true
    }
  }

  /// First step with unmet required fields — the resume target (D6).
  public var resumeStep: Int {
    (1...Self.stepCount).first { !isStepComplete($0) } ?? Self.stepCount
  }
}

// MARK: - Patch builders (D5)

extension OnboardingDraft {
  /// Only the given step's fields; nullable columns send explicit null when
  /// cleared. `upload_attachment_ids` stays absent everywhere (spec 032 §8).
  /// Step 3 is the only builder touching 1RM — never called from the
  /// nine-card edits (risk 6: the lock is structural, not an if).
  public func patch(forStep step: Int) -> OnboardingPatch {
    var patch = OnboardingPatch()
    switch step {
    case 1:
      patch.unitPreference = Self.ifSet(unitPreference)
      patch.gender = Self.ifSet(gender)
      patch.birthDate = Self.ifSet(birthDate)
      patch.heightCm = Self.ifSet(heightCm)
      patch.weightKg = Self.ifSet(weightKg)
    case 2:
      patch.trainingYears = Self.ifSet(trainingYears)
      patch.squatStance = Self.ifSet(squatStance)
      patch.deadliftStyle = Self.ifSet(deadliftStyle)
      patch.benchGrip = Self.nullable(benchGrip)
    case 3:
      patch.squat1RMKg = Self.ifSet(squat1RMKg)
      patch.bench1RMKg = Self.ifSet(bench1RMKg)
      patch.deadlift1RMKg = Self.ifSet(deadlift1RMKg)
    case 4:
      if trainingDaysUncertain == true {
        patch.trainingDays = .null
      } else {
        // zod min(2): an undersized selection stays absent — never ship an
        // invalid array that would 400 the whole PUT (risk 3).
        patch.trainingDays =
          (2...6).contains(trainingDays.count) ? .value(trainingDays) : .absent
      }
      patch.gymTier = Self.ifSet(gymTier)
      patch.equipmentOverrides =
        equipmentOverrides.isEmpty ? .null : .value(equipmentOverrides)
    case 5:
      patch.dailyLifeIntensity = Self.ifSet(dailyLifeIntensity)
      patch.lifeStress = Self.ifSet(lifeStress)
      patch.recoverySpeed = Self.ifSet(recoverySpeed)
      patch.sleepHours = Self.ifSet(sleepHours)
    case 6:
      patch.muscleGroupsToStrengthen =
        muscleGroupsToStrengthen.isEmpty ? .null : .value(muscleGroupsToStrengthen)
    case 7:
      patch.injuryNotes = Self.nullableText(injuryNotes)
      patch.injuryAreas = injuryAreas.isEmpty ? .null : .value(injuryAreas)
      patch.isCompeting = Self.ifSet(isCompeting)
      patch.competitionDate = isCompeting == true ? Self.nullable(competitionDate) : .null
      patch.targetWeightClass = Self.nullableText(targetWeightClass)
      patch.noteToCoach = Self.nullableText(noteToCoach)
    default:
      break
    }
    return patch
  }

  /// Whole-draft patch — the pre-complete catch-all PUT (D6: re-sends
  /// anything a failed step PUT may have dropped).
  public func fullPatch() -> OnboardingPatch {
    var merged = OnboardingPatch()
    for step in 1...Self.stepCount {
      merged.merge(patch(forStep: step))
    }
    return merged
  }

  /// Required (non-nullable) column: unset → absent.
  private static func ifSet<Value: Equatable & Sendable>(_ value: Value?) -> Patch<Value> {
    value.map(Patch.value) ?? .absent
  }

  /// Nullable column: unset → explicit clear.
  private static func nullable<Value: Equatable & Sendable>(_ value: Value?) -> Patch<Value> {
    value.map(Patch.value) ?? .null
  }

  /// Text column (zod min 1): trimmed-empty → explicit clear.
  private static func nullableText(_ text: String) -> Patch<String> {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? .null : .value(trimmed)
  }
}

extension OnboardingPatch {
  /// Field-wise overlay: non-absent fields of `other` win.
  fileprivate mutating func merge(_ other: OnboardingPatch) {
    unitPreference = Self.pick(unitPreference, other.unitPreference)
    gender = Self.pick(gender, other.gender)
    birthDate = Self.pick(birthDate, other.birthDate)
    heightCm = Self.pick(heightCm, other.heightCm)
    weightKg = Self.pick(weightKg, other.weightKg)
    trainingYears = Self.pick(trainingYears, other.trainingYears)
    squatStance = Self.pick(squatStance, other.squatStance)
    deadliftStyle = Self.pick(deadliftStyle, other.deadliftStyle)
    benchGrip = Self.pick(benchGrip, other.benchGrip)
    squat1RMKg = Self.pick(squat1RMKg, other.squat1RMKg)
    bench1RMKg = Self.pick(bench1RMKg, other.bench1RMKg)
    deadlift1RMKg = Self.pick(deadlift1RMKg, other.deadlift1RMKg)
    trainingDays = Self.pick(trainingDays, other.trainingDays)
    gymTier = Self.pick(gymTier, other.gymTier)
    equipmentOverrides = Self.pick(equipmentOverrides, other.equipmentOverrides)
    dailyLifeIntensity = Self.pick(dailyLifeIntensity, other.dailyLifeIntensity)
    lifeStress = Self.pick(lifeStress, other.lifeStress)
    recoverySpeed = Self.pick(recoverySpeed, other.recoverySpeed)
    sleepHours = Self.pick(sleepHours, other.sleepHours)
    muscleGroupsToStrengthen = Self.pick(
      muscleGroupsToStrengthen, other.muscleGroupsToStrengthen)
    uploadAttachmentIds = Self.pick(uploadAttachmentIds, other.uploadAttachmentIds)
    injuryNotes = Self.pick(injuryNotes, other.injuryNotes)
    injuryAreas = Self.pick(injuryAreas, other.injuryAreas)
    isCompeting = Self.pick(isCompeting, other.isCompeting)
    competitionDate = Self.pick(competitionDate, other.competitionDate)
    targetWeightClass = Self.pick(targetWeightClass, other.targetWeightClass)
    noteToCoach = Self.pick(noteToCoach, other.noteToCoach)
  }

  private static func pick<Value>(
    _ base: Patch<Value>,
    _ overlay: Patch<Value>
  ) -> Patch<Value> {
    overlay == .absent ? base : overlay
  }
}

// MARK: - 422 missing_fields → step mapping (D12)

extension OnboardingDraft {
  /// Backend completion gate fields (18 + conditional competition_date)
  /// mapped onto wizard steps; unknown fields return nil.
  public static func step(forMissingField field: String) -> Int? {
    switch field {
    case "unit_preference", "gender", "birth_date", "height_cm", "weight_kg":
      1
    case "training_years", "squat_stance", "deadlift_style":
      2
    case "squat_1rm_kg", "bench_1rm_kg", "deadlift_1rm_kg":
      3
    case "training_days", "gym_tier":
      4
    case "daily_life_intensity", "life_stress", "recovery_speed", "sleep_hours":
      5
    case "is_competing", "competition_date":
      7
    default:
      nil
    }
  }

  /// Earliest step covering any of the 422 `missing_fields` (D12).
  public static func earliestStep(forMissingFields fields: [String]) -> Int? {
    fields.compactMap(step(forMissingField:)).min()
  }
}
