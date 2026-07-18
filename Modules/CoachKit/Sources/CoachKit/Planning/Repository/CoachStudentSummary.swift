import Foundation

public struct CoachStudentRecentWeek: Hashable, Sendable {
  public let trainedDays: Int
  public let plannedDays: Int

  public init(trainedDays: Int, plannedDays: Int) {
    self.trainedDays = trainedDays
    self.plannedDays = plannedDays
  }
}

public struct CoachStudentSummary: Hashable, Identifiable, Sendable {
  public let id: UUID
  public let displayName: String
  public let status: CoachStudentStatus
  public let competitionDate: String?
  public let recentFourWeeks: [CoachStudentRecentWeek]?

  public init(
    id: UUID,
    displayName: String,
    status: CoachStudentStatus,
    competitionDate: String? = nil,
    recentFourWeeks: [CoachStudentRecentWeek]? = nil
  ) {
    self.id = id
    self.displayName = displayName
    self.status = status
    self.competitionDate = competitionDate
    self.recentFourWeeks = recentFourWeeks
  }
}
