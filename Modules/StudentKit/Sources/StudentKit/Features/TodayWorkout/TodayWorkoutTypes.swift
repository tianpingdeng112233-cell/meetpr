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
  public var prescribed: PrescribedSet
  public var actualWeight: Decimal?
  public var actualReps: Int?
  public var actualRPE: Decimal?
  public var completed: Bool
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
    self.loggedSetID = loggedSetID
  }
}

public struct TodayWorkoutRestTimerState: Equatable, Sendable {
  /// Wall-clock end; remaining time stays correct across background trips.
  public let endsAt: Date
  /// Progress-bar denominator.
  public let totalSeconds: Int
}
