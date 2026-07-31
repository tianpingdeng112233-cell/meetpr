import Foundation

/// The highest completed, non-failed competition-lift weight recorded for one
/// student and lift family. This state is independent from e1RM point
/// eligibility so sets such as a six-rep deadlift still establish the
/// measured-weight PR baseline.
public struct E1RMWeightBaseline: Codable, Hashable, Sendable {
  public let studentId: UUID
  public let family: LiftFamily
  public let maxWeightKg: Double
  public let setLogId: UUID
  public let achievedAt: Date
  /// The baseline value this record dethroned, kept so PR derivation that
  /// resumes after a replay already advanced the baseline (same set log) can
  /// still report the genuine prior record. Optional: pre-existing persisted
  /// baselines decode as nil.
  public let previousMaxWeightKg: Double?

  public init(
    studentId: UUID,
    family: LiftFamily,
    maxWeightKg: Double,
    setLogId: UUID,
    achievedAt: Date,
    previousMaxWeightKg: Double? = nil
  ) {
    self.studentId = studentId
    self.family = family
    self.maxWeightKg = maxWeightKg
    self.setLogId = setLogId
    self.achievedAt = achievedAt
    self.previousMaxWeightKg = previousMaxWeightKg
  }
}
