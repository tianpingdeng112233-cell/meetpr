import CoreModels
import Foundation
import RepositoryContracts

/// Demo/preview onboarding store (spec 032 §9). Mirrors the backend
/// semantics the UI depends on: three-state patch merge, the 18+1 completion
/// gate (snake_case field names verbatim), the post-completion 1RM lock, and
/// idempotent complete.
public actor InMemoryOnboardingRepository: OnboardingRepository {
  private let studentId: UUID
  private var profile: OnboardingProfile?
  private let now: @Sendable () -> Date

  public init(
    studentId: UUID,
    seed: OnboardingProfile? = nil,
    now: @escaping @Sendable () -> Date = { Date() }
  ) {
    self.studentId = studentId
    self.profile = seed
    self.now = now
  }

  public func fetchProfile(studentId: UUID) async throws -> OnboardingProfile? {
    guard studentId == self.studentId else { return nil }
    return profile
  }

  public func upsert(_ patch: OnboardingPatch) async throws -> OnboardingProfile {
    let timestamp = now()
    let current =
      profile
      ?? OnboardingProfile(userId: studentId, createdAt: timestamp, updatedAt: timestamp)

    if current.completedAt != nil, patch.touchesOneRM {
      throw OnboardingError.oneRMLocked
    }

    let updated = Self.applied(patch, to: current, updatedAt: timestamp)
    profile = updated
    return updated
  }

  public func complete() async throws -> OnboardingProfile {
    guard let current = profile else {
      throw OnboardingError.incomplete(missingFields: Self.requiredFields)
    }

    let missing = Self.missingFields(of: current)
    guard missing.isEmpty else {
      throw OnboardingError.incomplete(missingFields: missing)
    }

    if current.completedAt != nil {
      return current  // idempotent: original completed_at survives
    }

    let completed = Self.applied(
      OnboardingPatch.empty, to: current, updatedAt: now(), completedAt: now())
    profile = completed
    return completed
  }

  // MARK: - Completion gate mirror (backend handlers/onboarding.ts)

  static let requiredFields: [String] = [
    "unit_preference", "gender", "birth_date", "height_cm", "weight_kg",
    "training_years", "squat_stance", "deadlift_style",
    "squat_1rm_kg", "bench_1rm_kg", "deadlift_1rm_kg",
    "training_days", "gym_tier",
    "daily_life_intensity", "life_stress", "recovery_speed", "sleep_hours",
    "is_competing",
  ]

  static func missingFields(of profile: OnboardingProfile) -> [String] {
    var missing: [String] = []
    func check(_ isMissing: Bool, _ field: String) {
      if isMissing { missing.append(field) }
    }
    check(profile.unitPreference == nil, "unit_preference")
    check(profile.gender == nil, "gender")
    check(profile.birthDate == nil, "birth_date")
    check(profile.heightCm == nil, "height_cm")
    check(profile.weightKg == nil, "weight_kg")
    check(profile.trainingYears == nil, "training_years")
    check(profile.squatStance == nil, "squat_stance")
    check(profile.deadliftStyle == nil, "deadlift_style")
    check(profile.squat1RMKg == nil, "squat_1rm_kg")
    check(profile.bench1RMKg == nil, "bench_1rm_kg")
    check(profile.deadlift1RMKg == nil, "deadlift_1rm_kg")
    check(profile.trainingDays.isEmpty, "training_days")
    check(profile.gymTier == nil, "gym_tier")
    check(profile.dailyLifeIntensity == nil, "daily_life_intensity")
    check(profile.lifeStress == nil, "life_stress")
    check(profile.recoverySpeed == nil, "recovery_speed")
    check(profile.sleepHours == nil, "sleep_hours")
    check(profile.isCompeting == nil, "is_competing")
    // Conditionally required (is_competing = true).
    check(profile.isCompeting == true && profile.competitionDate == nil, "competition_date")
    return missing
  }

  // MARK: - Patch application (absent keeps / null clears / value writes)

  static func applied(
    _ patch: OnboardingPatch,
    to current: OnboardingProfile,
    updatedAt: Date,
    completedAt: Date? = nil
  ) -> OnboardingProfile {
    func merge<Value>(_ field: Patch<Value>, _ existing: Value?) -> Value? {
      switch field {
      case .absent: existing
      case .null: nil
      case .value(let value): value
      }
    }
    func mergeArray<Value>(_ field: Patch<[Value]>, _ existing: [Value]) -> [Value] {
      switch field {
      case .absent: existing
      case .null: []
      case .value(let value): value
      }
    }
    return OnboardingProfile(
      userId: current.userId,
      unitPreference: merge(patch.unitPreference, current.unitPreference),
      gender: merge(patch.gender, current.gender),
      birthDate: merge(patch.birthDate, current.birthDate),
      heightCm: merge(patch.heightCm, current.heightCm),
      weightKg: merge(patch.weightKg, current.weightKg),
      trainingYears: merge(patch.trainingYears, current.trainingYears),
      squatStance: merge(patch.squatStance, current.squatStance),
      deadliftStyle: merge(patch.deadliftStyle, current.deadliftStyle),
      benchGrip: merge(patch.benchGrip, current.benchGrip),
      squat1RMKg: merge(patch.squat1RMKg, current.squat1RMKg),
      bench1RMKg: merge(patch.bench1RMKg, current.bench1RMKg),
      deadlift1RMKg: merge(patch.deadlift1RMKg, current.deadlift1RMKg),
      trainingDays: mergeArray(patch.trainingDays, current.trainingDays),
      gymTier: merge(patch.gymTier, current.gymTier),
      equipmentOverrides: mergeArray(patch.equipmentOverrides, current.equipmentOverrides),
      dailyLifeIntensity: merge(patch.dailyLifeIntensity, current.dailyLifeIntensity),
      lifeStress: merge(patch.lifeStress, current.lifeStress),
      recoverySpeed: merge(patch.recoverySpeed, current.recoverySpeed),
      sleepHours: merge(patch.sleepHours, current.sleepHours),
      muscleGroupsToStrengthen: mergeArray(
        patch.muscleGroupsToStrengthen, current.muscleGroupsToStrengthen),
      uploadAttachmentIds: mergeArray(patch.uploadAttachmentIds, current.uploadAttachmentIds),
      injuryNotes: merge(patch.injuryNotes, current.injuryNotes),
      injuryAreas: mergeArray(patch.injuryAreas, current.injuryAreas),
      isCompeting: merge(patch.isCompeting, current.isCompeting),
      competitionDate: merge(patch.competitionDate, current.competitionDate),
      targetWeightClass: merge(patch.targetWeightClass, current.targetWeightClass),
      noteToCoach: merge(patch.noteToCoach, current.noteToCoach),
      completedAt: completedAt ?? current.completedAt,
      createdAt: current.createdAt,
      updatedAt: updatedAt
    )
  }
}
