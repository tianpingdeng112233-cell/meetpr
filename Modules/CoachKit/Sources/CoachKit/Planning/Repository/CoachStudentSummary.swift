import Foundation

public struct CoachStudentSummary: Hashable, Identifiable, Sendable {
  public let id: UUID
  public let displayName: String
  public let status: CoachStudentStatus

  public init(
    id: UUID,
    displayName: String,
    status: CoachStudentStatus
  ) {
    self.id = id
    self.displayName = displayName
    self.status = status
  }
}
