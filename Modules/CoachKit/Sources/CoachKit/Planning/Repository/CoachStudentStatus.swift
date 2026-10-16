import Foundation

public enum CoachStudentStatus: Hashable, Sendable {
  case active
  case abnormal(reason: AbnormalReason)
}
