import CoreModels
import Foundation

@testable import CoachKit

@available(iOS 17.0, macOS 14.0, *)
extension PlanningFixtures {
  static func studentWithoutOneRM() -> CoachStudentSummary {
    CoachStudentSummary(
      id: uuid(14),
      displayName: "赵安然",
      status: .inEvaluation(remainingDays: 6, remainingHours: 2)
    )
  }
}
