import Foundation

/// One estimated-1RM data point, computed locally each time the student
/// completes a set (spec 028). Distinct from the locked 1RM profile field:
/// e1RM is a per-set estimate and never writes back to 1RM (PRD §5 #16).
public struct E1RMHistoryPoint: Codable, Hashable, Sendable, Identifiable {
  public let id: UUID
  public let studentId: UUID
  /// Catalog exercise identity (variation-level): squat / high-bar squat /
  /// lunge each keep an independent history and PR lineage.
  public let exerciseId: UUID
  public let setLogId: UUID
  public let computedAt: Date
  public let e1RMKg: Double
  public let sourceWeightKg: Double
  public let sourceReps: Int
  public let sourceRPE: Double?

  public init(
    id: UUID,
    studentId: UUID,
    exerciseId: UUID,
    setLogId: UUID,
    computedAt: Date,
    e1RMKg: Double,
    sourceWeightKg: Double,
    sourceReps: Int,
    sourceRPE: Double?
  ) {
    self.id = id
    self.studentId = studentId
    self.exerciseId = exerciseId
    self.setLogId = setLogId
    self.computedAt = computedAt
    self.e1RMKg = e1RMKg
    self.sourceWeightKg = sourceWeightKg
    self.sourceReps = sourceReps
    self.sourceRPE = sourceRPE
  }
}
