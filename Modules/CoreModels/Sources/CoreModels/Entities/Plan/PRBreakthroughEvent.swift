import Foundation

/// A detected e1RM personal-record breakthrough (spec 028). Student-facing
/// only: the coach is never pushed PR events (PRD §5 #16), they read the
/// growth curve instead.
public struct PRBreakthroughEvent: Codable, Hashable, Sendable, Identifiable {
  public let id: UUID
  public let studentId: UUID
  public let exerciseId: UUID
  /// The E1RMHistoryPoint that produced this breakthrough.
  public let pointId: UUID
  public let breakthroughE1RMKg: Double
  public let previousMaxE1RMKg: Double
  public let occurredAt: Date
  /// Set when the student dismisses the banner; nil events re-surface on launch.
  public let acknowledgedAt: Date?

  public init(
    id: UUID,
    studentId: UUID,
    exerciseId: UUID,
    pointId: UUID,
    breakthroughE1RMKg: Double,
    previousMaxE1RMKg: Double,
    occurredAt: Date,
    acknowledgedAt: Date?
  ) {
    self.id = id
    self.studentId = studentId
    self.exerciseId = exerciseId
    self.pointId = pointId
    self.breakthroughE1RMKg = breakthroughE1RMKg
    self.previousMaxE1RMKg = previousMaxE1RMKg
    self.occurredAt = occurredAt
    self.acknowledgedAt = acknowledgedAt
  }

  public func acknowledged(at date: Date) -> PRBreakthroughEvent {
    PRBreakthroughEvent(
      id: id,
      studentId: studentId,
      exerciseId: exerciseId,
      pointId: pointId,
      breakthroughE1RMKg: breakthroughE1RMKg,
      previousMaxE1RMKg: previousMaxE1RMKg,
      occurredAt: occurredAt,
      acknowledgedAt: date
    )
  }
}
