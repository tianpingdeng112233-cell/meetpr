import CoreModels
import Foundation

public struct CoachStudentSummary: Hashable, Identifiable, Sendable {
  public let id: UUID
  public let profile: StudentProfile
  public let displayName: String
  public let status: CoachStudentStatus

  public init(
    id: UUID,
    profile: StudentProfile,
    displayName: String,
    status: CoachStudentStatus
  ) {
    self.id = id
    self.profile = profile
    self.displayName = displayName
    self.status = status
  }
}
