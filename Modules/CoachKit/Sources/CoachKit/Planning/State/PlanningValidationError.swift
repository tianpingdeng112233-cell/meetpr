import Foundation

public enum PlanningValidationError: Error, Equatable, LocalizedError, Sendable {
  case missingStudent
  case invalidDuration
  case evaluationStudentRequiresOneWeek
  case invalidFrequency
  case assignmentOutsideTrainingDays
  case incompleteMainLiftVariants
  case incompleteW1SetSpecs
  case invalidW1SetSpec

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
    case .incompleteW1SetSpecs:
      "每个已加入计划的动作都需要填写 Week 1 组数、次数和强度。"
    case .invalidW1SetSpec:
      "Week 1 组数、次数或强度超出范围。"
    }
  }
}
