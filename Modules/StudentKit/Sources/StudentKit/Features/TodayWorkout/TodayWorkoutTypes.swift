import CoreModels
import Foundation

// Top-level homes for TodayWorkoutViewModel's value types (typealiased back
// onto the VM) — keeps the @Observable class body inside SwiftLint's
// type_body_length budget.

public struct TodayWorkoutSetRowDraft: Equatable, Sendable, Identifiable {
  public let id: UUID
  public let planExerciseID: UUID
  /// Catalog exercise identity (variation-level) — spec 028 keys e1RM
  /// history and PR detection per exercise+variation, not per plan slot.
  public let exerciseID: UUID
  public let exerciseName: String
  public let exerciseNameEn: String?
  public let isAccessory: Bool
  /// Coach-assigned plan role (`ExerciseType.mainLift`) — gates the e1RM-based
  /// weight suggestion; variations and accessories fill last logged weight
  /// instead.
  public let isMainLift: Bool
  public var prescribed: PrescribedSet
  public var actualWeight: Decimal?
  public var actualReps: Int?
  public var actualRPE: Decimal?
  public var completed: Bool
  public var failed: Bool
  public var assumed: Bool
  public var loggedSetID: UUID?

  public init(
    id: UUID,
    planExerciseID: UUID,
    exerciseID: UUID,
    exerciseName: String,
    exerciseNameEn: String? = nil,
    isAccessory: Bool,
    isMainLift: Bool = false,
    prescribed: PrescribedSet,
    actualWeight: Decimal? = nil,
    actualReps: Int? = nil,
    actualRPE: Decimal? = nil,
    completed: Bool = false,
    failed: Bool = false,
    assumed: Bool = false,
    loggedSetID: UUID? = nil
  ) {
    self.id = id
    self.planExerciseID = planExerciseID
    self.exerciseID = exerciseID
    self.exerciseName = exerciseName
    self.exerciseNameEn = exerciseNameEn
    self.isAccessory = isAccessory
    self.isMainLift = isMainLift
    self.prescribed = prescribed
    self.actualWeight = actualWeight
    self.actualReps = actualReps
    self.actualRPE = actualRPE
    self.completed = completed
    self.failed = failed
    self.assumed = assumed
    self.loggedSetID = loggedSetID
  }

  public var allowsPlateLoadingGuidance: Bool {
    !isAccessory
  }

  public var displayExerciseName: String {
    guard Locale.current.language.languageCode?.identifier == "en",
      let exerciseNameEn = exerciseNameEn?.trimmingCharacters(in: .whitespacesAndNewlines),
      !exerciseNameEn.isEmpty
    else {
      return exerciseName
    }
    return exerciseNameEn
  }

  /// Merges a persisted recordSet result into the draft. `assumed` must come along:
  /// a real save overwrites an assumed record server-side, and without the write-back
  /// the ask-coach entry stays hidden until a full reload (sharing eligibility keys on it).
  public mutating func applyPersistResult(
    _ persisted: StudentSetLog,
    completed: Bool,
    failed: Bool
  ) {
    self.completed = completed
    self.failed = failed
    loggedSetID = persisted.id
    assumed = persisted.assumed
  }
}

public struct TodayWorkoutRestTimerState: Equatable, Sendable {
  /// Wall-clock end; remaining time stays correct across background trips.
  public let endsAt: Date
  /// Progress-bar denominator.
  public let totalSeconds: Int
}

public struct ExerciseReference: Equatable, Sendable {
  public let last: ExerciseReferenceSet?
  public let best: ExerciseReferenceSet?

  public init(last: ExerciseReferenceSet?, best: ExerciseReferenceSet?) {
    self.last = last
    self.best = best
  }

  public var hasValue: Bool {
    last != nil || best != nil
  }
}

struct SetWeightSuggestion: Equatable, Sendable {
  enum Basis: Equatable, Sendable {
    case previousSet
    case e1RM(Double)
    /// Most recent logged weight for this exercise from an earlier session
    /// (variation / accessory path).
    case lastLogged
  }

  let weightKg: Decimal
  let basis: Basis
}

enum SetWeightSuggestionUnavailableReason: Equatable, Sendable {
  case noEligibleE1RMHistory
  case missingPrescribedRPE
  case missingPrescribedReps
  case prescribedRepsOutsideSupportedRange
  case prescribedRPEBelowSupportedRange
  case prescribedRPEAboveSupportedRange
  case noExerciseHistory

  var message: String {
    switch self {
    case .noEligibleE1RMHistory:
      StudentStrings.localized(.todayWorkoutTypes001)
    case .missingPrescribedRPE:
      StudentStrings.localized(.todayWorkoutTypes002)
    case .missingPrescribedReps:
      StudentStrings.localized(.todayWorkoutTypes003)
    case .prescribedRepsOutsideSupportedRange:
      StudentStrings.localized(.todayWorkoutTypes004)
    case .prescribedRPEBelowSupportedRange:
      StudentStrings.localized(.todayWorkoutTypes005)
    case .prescribedRPEAboveSupportedRange:
      StudentStrings.localized(.todayWorkoutTypes006)
    case .noExerciseHistory:
      StudentStrings.localized(.todayWorkoutTypes007)
    }
  }
}

struct SetWeightSuggestionOutcome: Equatable, Sendable {
  let suggestion: SetWeightSuggestion?
  let unavailableReason: SetWeightSuggestionUnavailableReason?

  static let unavailableWithoutReason = SetWeightSuggestionOutcome(
    suggestion: nil,
    unavailableReason: nil
  )
}

public struct ExerciseReferenceSet: Equatable, Sendable {
  public let reps: Int
  public let weightKg: Double
  public let e1RMKg: Double?

  public init(reps: Int, weightKg: Double, e1RMKg: Double? = nil) {
    self.reps = reps
    self.weightKg = weightKg
    self.e1RMKg = e1RMKg
  }

  init(point: E1RMHistoryPoint) {
    self.reps = point.sourceReps
    self.weightKg = point.sourceWeightKg
    self.e1RMKg = point.e1RMKg
  }
}

public struct TodayWorkoutPlanContext: Equatable, Sendable {
  public let planKind: PlanKind
  public let weekIndex: Int
  public let startDate: Date

  public init(planKind: PlanKind, weekIndex: Int, startDate: Date) {
    self.planKind = planKind
    self.weekIndex = weekIndex
    self.startDate = startDate
  }
}

func lastAndBest(
  from points: [E1RMHistoryPoint]
) -> (last: E1RMHistoryPoint?, best: E1RMHistoryPoint?) {
  let last = points.max { $0.computedAt < $1.computedAt }
  let best = points.max { $0.e1RMKg < $1.e1RMKg }
  return (last, best)
}
