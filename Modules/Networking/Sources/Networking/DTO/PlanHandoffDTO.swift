import CoreModels
import Foundation

public struct PlanHandoffDTO: Decodable, Sendable {
  public let currentPlanID: UUID?
  public let plans: [Entry]

  public struct Entry: Decodable, Sendable {
    public let plan: PlanDTO
    public let completedTrainingDays: Int
    public let totalTrainingDays: Int
    public let handoffStatus: StudentPlanHandoff.Status

    public init(from decoder: Decoder) throws {
      plan = try PlanDTO(from: decoder)
      let container = try decoder.container(keyedBy: CodingKeys.self)
      completedTrainingDays = try container.decode(Int.self, forKey: .completedTrainingDays)
      totalTrainingDays = try container.decode(Int.self, forKey: .totalTrainingDays)
      handoffStatus = try container.decode(StudentPlanHandoff.Status.self, forKey: .handoffStatus)
    }

    private enum CodingKeys: String, CodingKey {
      case completedTrainingDays, totalTrainingDays, handoffStatus
    }
  }

  public var handoff: StudentPlanHandoff {
    StudentPlanHandoff(
      currentPlanID: currentPlanID,
      plans: plans.map {
        StudentPlanHandoff.Entry(
          id: $0.plan.id, name: $0.plan.name, weeks: $0.plan.planWeeks,
          completedTrainingDays: $0.completedTrainingDays, totalTrainingDays: $0.totalTrainingDays,
          status: $0.handoffStatus)
      })
  }

  private enum CodingKeys: String, CodingKey {
    case currentPlanID = "currentPlanId"
    case plans
  }
}
