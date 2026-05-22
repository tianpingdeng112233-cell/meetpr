import CoreModels
import Foundation

/// Read-only access to the student's published plan projection.
/// `studentID` is the current user's; the UI layer reads it from Session and passes it in.
public protocol StudentPlanRepository: Sendable {
  func fetchCurrentPlan(studentID: UUID) async throws -> StudentPlanView?
  /// Returns `nil` when the given day has no training.
  func fetchDay(studentID: UUID, date: Date) async throws -> StudentPlanDay?
  /// All days in the current cycle; the UI groups them by week.
  func fetchCycleDays(studentID: UUID) async throws -> [StudentPlanDay]
}
