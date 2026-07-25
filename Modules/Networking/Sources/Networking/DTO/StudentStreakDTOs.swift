import Foundation
import RepositoryContracts

public struct StudentStreakResponseDTO: Codable, Equatable, Sendable {
  public let streak: StudentStreakDTO?

  public init(streak: StudentStreakDTO?) {
    self.streak = streak
  }
}

public struct StudentStreakDTO: Codable, Equatable, Sendable {
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

  public func toDomain() -> StudentTrainingStreak {
    StudentTrainingStreak(
      current: current,
      asOf: asOf,
      startedOn: startedOn,
      lastSessionDate: lastSessionDate
    )
  }
}
