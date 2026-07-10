import CoreModels
import Foundation

public enum PlanDayShiftError: Error, Equatable, Sendable {
  case planNotActive
  case onlyToday
  case dayHasLogs
  case targetNotRestDay
  case unavailable

  public init?(machineCode: String?) {
    switch machineCode {
    case "PLAN_NOT_ACTIVE": self = .planNotActive
    case "SHIFT_ONLY_TODAY": self = .onlyToday
    case "SHIFT_DAY_HAS_LOGS": self = .dayHasLogs
    case "SHIFT_TARGET_NOT_REST_DAY": self = .targetNotRestDay
    default: return nil
    }
  }
}

/// Access to the student's published plan projection and day-shift mutations.
/// `studentID` is the current user's; the UI layer reads it from Session and passes it in.
public protocol StudentPlanRepository: Sendable {
  func fetchCurrentPlan(studentID: UUID) async throws -> StudentPlanView?
  /// Returns `nil` when the given day has no training.
  func fetchDay(studentID: UUID, date: Date) async throws -> StudentPlanDay?
  /// All days in the current cycle; the UI groups them by week.
  func fetchCycleDays(studentID: UUID) async throws -> [StudentPlanDay]
  func shiftDay(id: UUID, to date: Date, studentID: UUID) async throws
  func cancelShift(dayID: UUID, studentID: UUID) async throws
}

extension StudentPlanRepository {
  public func shiftDay(id: UUID, to date: Date, studentID: UUID) async throws {
    throw PlanDayShiftError.unavailable
  }

  public func cancelShift(dayID: UUID, studentID: UUID) async throws {
    throw PlanDayShiftError.unavailable
  }
}
