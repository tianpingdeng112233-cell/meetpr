import CoreModels
import Foundation

@testable import StudentKit

/// Recording tests explicitly require an unsettled first day; Demo includes settled history.
enum StudentAddedTestPlan {
  static func unsettledDemo() -> StudentPlanView {
    let plan = StudentDemoSeed.makePlanView()
    return StudentPlanView(
      cycleID: plan.cycleID, weekIndex: plan.weekIndex, startDate: plan.startDate,
      endDate: plan.endDate, planKind: plan.planKind, publishedAt: plan.publishedAt,
      days: plan.days.map { $0.replacingCompletion(completedAt: nil, source: nil) })
  }
}
