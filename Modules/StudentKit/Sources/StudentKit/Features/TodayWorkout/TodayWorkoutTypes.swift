import CoreModels
import Foundation
import RepositoryContracts

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
  public var prescribed: PrescribedSet
  public var actualWeight: Decimal?
  public var actualReps: Int?
  public var actualRPE: Decimal?
  public var completed: Bool
  public var failed: Bool
  public var loggedSetID: UUID?

  public init(
    id: UUID,
    planExerciseID: UUID,
    exerciseID: UUID,
    exerciseName: String,
    prescribed: PrescribedSet,
    actualWeight: Decimal? = nil,
    actualReps: Int? = nil,
    actualRPE: Decimal? = nil,
    completed: Bool = false,
    failed: Bool = false,
    loggedSetID: UUID? = nil
  ) {
    self.id = id
    self.planExerciseID = planExerciseID
    self.exerciseID = exerciseID
    self.exerciseName = exerciseName
    self.prescribed = prescribed
    self.actualWeight = actualWeight
    self.actualReps = actualReps
    self.actualRPE = actualRPE
    self.completed = completed
    self.failed = failed
    self.loggedSetID = loggedSetID
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

public struct ExerciseReferenceSet: Equatable, Sendable {
  public let reps: Int
  public let weightKg: Double

  public init(reps: Int, weightKg: Double) {
    self.reps = reps
    self.weightKg = weightKg
  }

  init(point: E1RMHistoryPoint) {
    self.reps = point.sourceReps
    self.weightKg = point.sourceWeightKg
  }
}

public struct TodayWorkoutPlanContext: Equatable, Sendable {
  public let planKind: PlanKind
  public let weekIndex: Int
  public let startDate: Date
  let algorithmMetadata: PlanAlgorithmMetadata

  public init(
    planKind: PlanKind,
    weekIndex: Int,
    startDate: Date,
    blockType: String? = nil,
    mesocyclePhase: String? = nil,
    trainingMax: Decimal? = nil,
    tmSetAt: Date? = nil
  ) {
    self.planKind = planKind
    self.weekIndex = weekIndex
    self.startDate = startDate
    self.algorithmMetadata = PlanAlgorithmMetadata(
      blockType: blockType,
      mesocyclePhase: mesocyclePhase,
      trainingMax: trainingMax,
      tmSetAt: tmSetAt
    )
  }
}

public enum TodayWorkoutSessionPage: Equatable, Sendable {
  case loading
  case overview
  case inProgress(TrainingSession)
  case completed(TrainingSession)
}

public protocol RecentCompletedSessionDurationStoring: Sendable {
  func durationSeconds(studentID: UUID) -> Int?
  func record(durationSeconds: Int, studentID: UUID)
}

/// Persists the optional overview stat without adding a backend history
/// endpoint. The suite name makes cold-start behavior independently testable.
public struct UserDefaultsSessionDurationStore: RecentCompletedSessionDurationStoring {
  private let suiteName: String?

  public init(suiteName: String? = nil) {
    self.suiteName = suiteName
  }

  public func durationSeconds(studentID: UUID) -> Int? {
    let key = Self.key(studentID)
    guard defaults.object(forKey: key) != nil else { return nil }
    return defaults.integer(forKey: key)
  }

  public func record(durationSeconds: Int, studentID: UUID) {
    defaults.set(max(0, durationSeconds), forKey: Self.key(studentID))
  }

  private var defaults: UserDefaults {
    suiteName.flatMap { UserDefaults(suiteName: $0) } ?? .standard
  }

  private static func key(_ studentID: UUID) -> String {
    "meetpr.training.recent_completed_duration.\(studentID.uuidString)"
  }
}

enum TrainingSessionTimer {
  static func elapsedSeconds(for page: TodayWorkoutSessionPage, now: Date) -> Int? {
    switch page {
    case .loading, .overview:
      return nil
    case .inProgress(let session):
      return max(0, Int(now.timeIntervalSince(session.startedAt)))
    case .completed(let session):
      return max(0, session.durationSeconds)
    }
  }

  static func text(seconds: Int) -> String {
    let clamped = max(0, seconds)
    return "\(clamped / 60):\(twoDigit(clamped % 60))"
  }

  private static func twoDigit(_ value: Int) -> String {
    value < 10 ? "0\(value)" : "\(value)"
  }
}

func lastAndBest(
  from points: [E1RMHistoryPoint]
) -> (last: E1RMHistoryPoint?, best: E1RMHistoryPoint?) {
  let last = points.max { $0.computedAt < $1.computedAt }
  let best = points.max { $0.e1RMKg < $1.e1RMKg }
  return (last, best)
}
