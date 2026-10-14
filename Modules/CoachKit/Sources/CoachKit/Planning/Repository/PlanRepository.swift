import CoreModels
import Foundation
import Networking

public protocol PlanRepository: Sendable {
  func fetchCoachLogs(studentID: UUID, in range: ClosedRange<Date>) async throws
    -> [CoachSetLogDTO]?
  func fetchStudents() async throws -> [CoachStudentSummary]
  func fetchMainLiftCatalog() async throws -> [Exercise]
  func fetchAccessoryExercises(filters: AccessoryFilters) async throws -> [Exercise]
  func publishPlan(
    plan: TrainingPlan,
    days: [PlanDay],
    exercises: [PlanExercise],
    sets: [PlanSet]
  ) async throws
}

extension PlanRepository {
  public func fetchCoachLogs(studentID: UUID, in range: ClosedRange<Date>) async throws
    -> [CoachSetLogDTO]?
  {
    nil
  }
}
