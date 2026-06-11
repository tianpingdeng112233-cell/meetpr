import Foundation

/// Student→coach bind request (spec 031). Field-for-field mirror of the
/// backend bind_requests wire shape (backend spec 005 §endpoint B).
///
/// spec 033 extension point: the coach receive queue reuses this entity, and
/// the student BindGate's `.bound` branch will grow an evaluation-period
/// sub-route keyed on `skipEvaluation` — both consume these fields as-is.
public struct BindRequest: Codable, Hashable, Sendable, Identifiable {
  public let id: UUID
  public let studentId: UUID
  public let coachId: UUID
  /// Left join on coach_profiles — nil when the coach has no profile row;
  /// UI falls back to the literal "教练" (spec 031 risk 5).
  public let coachDisplayName: String?
  /// SET NULL when the originating code is deleted.
  public let inviteCodeId: UUID?
  public let status: BindRequestStatus
  public let submittedAt: Date
  /// Coach response time; stays nil for cancelled/expired.
  public let respondedAt: Date?
  /// NOT NULL on the wire: pending requests are created with +7d.
  public let expiredAt: Date
  public let skipEvaluation: Bool
  public let skipReason: String?

  public init(
    id: UUID,
    studentId: UUID,
    coachId: UUID,
    coachDisplayName: String? = nil,
    inviteCodeId: UUID? = nil,
    status: BindRequestStatus,
    submittedAt: Date,
    respondedAt: Date? = nil,
    expiredAt: Date,
    skipEvaluation: Bool = false,
    skipReason: String? = nil
  ) {
    self.id = id
    self.studentId = studentId
    self.coachId = coachId
    self.coachDisplayName = coachDisplayName
    self.inviteCodeId = inviteCodeId
    self.status = status
    self.submittedAt = submittedAt
    self.respondedAt = respondedAt
    self.expiredAt = expiredAt
    self.skipEvaluation = skipEvaluation
    self.skipReason = skipReason
  }
}
