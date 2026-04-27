import Foundation

public struct BindRequest: Codable, Hashable, Sendable, Identifiable {
  public let id: UUID
  public let studentID: UUID
  public let coachID: UUID
  public let inviteCodeID: UUID
  public let status: BindRequestStatus
  public let submittedAt: Date
  public let respondedAt: Date?
  public let expiredAt: Date?
  public let skipEvaluation: Bool
  public let skipReason: String?
  public let rejectionSilent: Bool

  public init(
    id: UUID,
    studentID: UUID,
    coachID: UUID,
    inviteCodeID: UUID,
    status: BindRequestStatus,
    submittedAt: Date,
    respondedAt: Date? = nil,
    expiredAt: Date? = nil,
    skipEvaluation: Bool = false,
    skipReason: String? = nil,
    rejectionSilent: Bool = true
  ) {
    self.id = id
    self.studentID = studentID
    self.coachID = coachID
    self.inviteCodeID = inviteCodeID
    self.status = status
    self.submittedAt = submittedAt
    self.respondedAt = respondedAt
    self.expiredAt = expiredAt
    self.skipEvaluation = skipEvaluation
    self.skipReason = skipReason
    self.rejectionSilent = rejectionSilent
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case studentID = "studentId"
    case coachID = "coachId"
    case inviteCodeID = "inviteCodeId"
    case status
    case submittedAt
    case respondedAt
    case expiredAt
    case skipEvaluation
    case skipReason
    case rejectionSilent
  }
}
