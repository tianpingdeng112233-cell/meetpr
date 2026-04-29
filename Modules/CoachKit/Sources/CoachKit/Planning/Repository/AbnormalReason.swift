import Foundation

public enum AbnormalReason: Hashable, Sendable {
  case noTrainingForDays(Int)
  case stuckOnWeek(Int)
}
