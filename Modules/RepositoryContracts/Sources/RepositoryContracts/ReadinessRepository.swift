import CoreModels
import Foundation

/// Student readiness check-in store (spec 030 §C). The full domain value
/// includes optional energy for backward compatibility with older check-ins.
/// V0.1 collects and reads the current day only — no score (ADR-001); the
/// coach side consumes the same fetch in spec 029's second pass.
public protocol ReadinessRepository: Sendable {
  /// Same-day resubmission overwrites (upsert by (studentId, checkinDate)).
  func submit(_ checkin: ReadinessCheckin) async throws
  /// `checkinDate` is "yyyy-MM-dd"; returns nil when nothing was filed.
  func fetchCheckin(studentId: UUID, checkinDate: String) async throws -> ReadinessCheckin?
}
