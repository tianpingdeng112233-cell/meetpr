import CoreModels
import Foundation

public protocol PlanRepository: Sendable {
  func fetchStudents() async throws -> [CoachStudentSummary]
  func fetchMainLiftCatalog() async throws -> [Exercise]
  func fetchAccessoryExercises(filters: AccessoryFilters) async throws -> [Exercise]
  func publishPlan(
    plan: TrainingPlan,
    days: [PlanDay],
    exercises: [PlanExercise]
  ) async throws
}
