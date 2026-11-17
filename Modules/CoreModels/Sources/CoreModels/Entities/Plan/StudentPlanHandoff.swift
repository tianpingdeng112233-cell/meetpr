import Foundation

/// Server-derived order and progress. Clients never infer current from dates or publication time.
public struct StudentPlanHandoff: Codable, Hashable, Sendable {
  public enum Status: String, Codable, Sendable {
    case current, upcoming, past
  }

  public struct Entry: Codable, Hashable, Sendable, Identifiable {
    public let id: UUID
    public let name: String
    public let weeks: Int
    public let completedTrainingDays: Int
    public let totalTrainingDays: Int
    public let status: Status

    public init(
      id: UUID, name: String, weeks: Int, completedTrainingDays: Int,
      totalTrainingDays: Int, status: Status
    ) {
      self.id = id
      self.name = name
      self.weeks = weeks
      self.completedTrainingDays = completedTrainingDays
      self.totalTrainingDays = totalTrainingDays
      self.status = status
    }
  }

  public let currentPlanID: UUID?
  public let plans: [Entry]

  public init(currentPlanID: UUID?, plans: [Entry]) {
    self.currentPlanID = currentPlanID
    self.plans = plans
  }
}
