import Foundation

/// Three-state partial update (spec 032 D5): the backend PUT is a re-entrant
/// upsert with zod `.strict()`, so "don't touch" and "explicitly clear" must
/// be distinguishable. `absent` keys never appear in the encoded JSON body;
/// `null` encodes a JSON null (clears the column).
public enum Patch<Value: Equatable & Sendable>: Equatable, Sendable {
  case absent
  case null
  case value(Value)

  public var valueOrNil: Value? {
    if case .value(let value) = self { return value }
    return nil
  }

  public var isAbsent: Bool { self == .absent }
}

/// PUT /students/me/onboarding payload, all 29 product fields patchable.
/// CoreModels owns the type; snake_case encoding (and the absent-key
/// omission) lives in Networking's OnboardingPatchDTO.
public struct OnboardingPatch: Equatable, Sendable {
  // Step 1
  public var unitPreference: Patch<UnitPreference> = .absent
  public var gender: Patch<Gender> = .absent
  public var birthDate: Patch<String> = .absent
  public var heightCm: Patch<Decimal> = .absent
  public var weightKg: Patch<Decimal> = .absent
  // Step 2
  public var trainingYears: Patch<Int> = .absent
  public var squatStance: Patch<SquatStance> = .absent
  public var deadliftStyle: Patch<DeadliftStance> = .absent
  public var benchGrip: Patch<BenchGrip> = .absent
  // Step 3
  public var squat1RMKg: Patch<Decimal> = .absent
  public var bench1RMKg: Patch<Decimal> = .absent
  public var deadlift1RMKg: Patch<Decimal> = .absent
  // Step 4
  public var trainingDays: Patch<[TrainingDay]> = .absent
  public var gymTier: Patch<GymTier> = .absent
  public var equipmentOverrides: Patch<[String]> = .absent
  // Step 5
  public var dailyLifeIntensity: Patch<Int> = .absent
  public var lifeStress: Patch<Int> = .absent
  public var recoverySpeed: Patch<Int> = .absent
  public var sleepHours: Patch<Int> = .absent
  // Step 6
  public var muscleGroupsToStrengthen: Patch<[MuscleGroup]> = .absent
  /// Full-replace semantics (backend spec 005 D17): absent = untouched,
  /// `[]` = delete every upload. NOT a nullable column — patch builders must
  /// never produce `.null` here (spec 032 risk 4).
  public var uploadAttachmentIds: Patch<[UUID]> = .absent
  // Step 7
  public var injuryNotes: Patch<String> = .absent
  public var injuryAreas: Patch<[InjuryArea]> = .absent
  public var isCompeting: Patch<Bool> = .absent
  public var competitionDate: Patch<String> = .absent
  public var targetWeightClass: Patch<String> = .absent
  public var noteToCoach: Patch<String> = .absent

  public init() {}

  public static let empty = OnboardingPatch()

  /// True for the three student-locked fields (403 ONE_RM_LOCKED after
  /// completion; spec 032 risk 6 — completed-path patch builders must keep
  /// this false by construction).
  public var touchesOneRM: Bool {
    !squat1RMKg.isAbsent || !bench1RMKg.isAbsent || !deadlift1RMKg.isAbsent
  }
}
