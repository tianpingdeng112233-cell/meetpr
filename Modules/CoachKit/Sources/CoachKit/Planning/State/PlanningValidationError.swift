import Foundation

public enum PlanningValidationError: Error, Equatable, LocalizedError, Sendable {
  case missingStudent
  case invalidDuration
  case evaluationStudentRequiresOneWeek
  case invalidFrequency
  case assignmentOutsideTrainingDays
  case incompleteMainLiftVariants

  public var errorDescription: String? {
    switch self {
    case .missingStudent:
      "请选择学员。"
    case .invalidDuration:
      "请选择 1 周或 4 周计划。"
    case .evaluationStudentRequiresOneWeek:
      "评估期内学员只能安排 1 周适应计划。"
    case .invalidFrequency:
      "三大项频率需要和训练日分配数量一致。"
    case .assignmentOutsideTrainingDays:
      "大项只能分配到学员档案里的训练日。"
    case .incompleteMainLiftVariants:
      "每个已分配主项都需要选择动作变式。"
    }
  }
}
