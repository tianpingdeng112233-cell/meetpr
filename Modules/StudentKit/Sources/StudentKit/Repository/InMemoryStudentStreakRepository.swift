import RepositoryContracts

public actor InMemoryStudentStreakRepository: StudentStreakRepository {
  private let streak: StudentTrainingStreak?

  public init(current: Int?) {
    streak = current.map {
      StudentTrainingStreak(
        current: $0,
        asOf: "2026-07-25",
        startedOn: nil,
        lastSessionDate: nil
      )
    }
  }

  public func currentStreak() async throws -> StudentTrainingStreak? {
    streak
  }
}
