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
      CoachPlanningStrings.missingStudent
    case .invalidDuration:
      CoachPlanningStrings.invalidDuration
    case .evaluationStudentRequiresOneWeek:
      CoachPlanningStrings.evaluationRequiresOneWeek
    case .invalidFrequency:
      CoachPlanningStrings.invalidFrequency
    case .assignmentOutsideTrainingDays:
      CoachPlanningStrings.assignmentOutsideTrainingDays
    case .incompleteMainLiftVariants:
      CoachPlanningStrings.incompleteMainLiftVariants
    case .incompleteW1SetSpecs:
      CoachPlanningStrings.incompleteWeekOneSetSpecs
    case .invalidW1SetSpec:
      CoachPlanningStrings.invalidWeekOneSetSpec
    }
  }
}
