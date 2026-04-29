import Foundation

public enum CoachStudentStatus: Hashable, Sendable {
  case inEvaluation(remainingDays: Int, remainingHours: Int)
  case active
  case abnormal(reason: AbnormalReason)
}
