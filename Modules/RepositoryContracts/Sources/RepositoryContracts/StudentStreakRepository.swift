import Foundation

public struct StudentTrainingStreak: Equatable, Sendable {
  public let current: Int
  public let asOf: String
  public let startedOn: String?
  public let lastSessionDate: String?

  public init(
    current: Int,
    asOf: String,
    startedOn: String?,
    lastSessionDate: String?
  ) {
    self.current = current
    self.asOf = asOf
    self.startedOn = startedOn
    self.lastSessionDate = lastSessionDate
  }
}

public protocol StudentStreakRepository: Sendable {
  /// `GET /students/me/streak`; missing data is represented as `nil`.
  func currentStreak() async throws -> StudentTrainingStreak?
}
