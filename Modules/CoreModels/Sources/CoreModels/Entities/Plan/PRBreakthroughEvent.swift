import Foundation

/// A detected measured-weight personal record (spec 050, 2026-07-28
/// amendment). The e1RM fields remain so strength headlines can keep their
/// existing projection; new events also carry the measured-weight baseline
/// used for the PR decision and celebration.
public struct PRBreakthroughEvent: Codable, Hashable, Sendable, Identifiable {
  public let id: UUID
  public let studentId: UUID
  public let exerciseId: UUID
  /// Resolved competition family for family-wide measured-weight baselines.
  /// Events persisted before spec 050 decode as nil.
  public let family: LiftFamily?
  /// Nil when the measured-weight PR set was not eligible for an e1RM point.
  public let pointId: UUID?
  /// Nil when the measured-weight PR set could not produce a valid e1RM.
  public let breakthroughE1RMKg: Double?
  public let previousMaxE1RMKg: Double?
  /// Nil only for events persisted before the measured-weight amendment.
  public let breakthroughWeightKg: Double?
  /// Nil only for events persisted before the measured-weight amendment.
  public let previousMaxWeightKg: Double?
  public let occurredAt: Date
  /// Set when the student dismisses the banner; nil events re-surface on launch.
  public let acknowledgedAt: Date?

  public init(
    id: UUID,
    studentId: UUID,
    exerciseId: UUID,
    family: LiftFamily? = nil,
    pointId: UUID?,
    breakthroughE1RMKg: Double?,
    previousMaxE1RMKg: Double?,
    breakthroughWeightKg: Double? = nil,
    previousMaxWeightKg: Double? = nil,
    occurredAt: Date,
    acknowledgedAt: Date?
  ) {
    self.id = id
    self.studentId = studentId
    self.exerciseId = exerciseId
    self.family = family
    self.pointId = pointId
    self.breakthroughE1RMKg = breakthroughE1RMKg
    self.previousMaxE1RMKg = previousMaxE1RMKg
    self.breakthroughWeightKg = breakthroughWeightKg
    self.previousMaxWeightKg = previousMaxWeightKg
    self.occurredAt = occurredAt
    self.acknowledgedAt = acknowledgedAt
  }

  public func acknowledged(at date: Date) -> PRBreakthroughEvent {
    PRBreakthroughEvent(
      id: id,
      studentId: studentId,
      exerciseId: exerciseId,
      family: family,
      pointId: pointId,
      breakthroughE1RMKg: breakthroughE1RMKg,
      previousMaxE1RMKg: previousMaxE1RMKg,
      breakthroughWeightKg: breakthroughWeightKg,
      previousMaxWeightKg: previousMaxWeightKg,
      occurredAt: occurredAt,
      acknowledgedAt: date
    )
  }
}
