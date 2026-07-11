import CoreModels
import Foundation

public enum PlanShiftError: Error, Equatable, Sendable {
  case planNotActive
  case onlyToday
  case alreadyStarted
  case notPlanStudent
  case noActiveShift
  case undoWindowPassed
  case unavailable

  public init?(machineCode: String?) {
    switch machineCode {
    case "PLAN_NOT_ACTIVE": self = .planNotActive
    case "SHIFT_ONLY_TODAY": self = .onlyToday
    case "ALREADY_STARTED": self = .alreadyStarted
    case "NOT_PLAN_STUDENT": self = .notPlanStudent
    case "NO_ACTIVE_SHIFT": self = .noActiveShift
    case "UNDO_WINDOW_PASSED": self = .undoWindowPassed
    default: return nil
    }
  }
}

public struct ShiftedPlanDay: Equatable, Sendable {
  public let dayID: UUID
  public let shiftedToDate: Date

  public init(dayID: UUID, shiftedToDate: Date) {
    self.dayID = dayID
    self.shiftedToDate = shiftedToDate
  }
}

public struct PlanShiftResult: Equatable, Sendable {
  public let batchID: UUID
  public let shiftedDays: [ShiftedPlanDay]
  public let totalShiftDays: Int

  public init(batchID: UUID, shiftedDays: [ShiftedPlanDay], totalShiftDays: Int) {
    self.batchID = batchID
    self.shiftedDays = shiftedDays
    self.totalShiftDays = totalShiftDays
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
  func shiftPlan(id: UUID, studentID: UUID) async throws -> PlanShiftResult
  func cancelPlanShift(id: UUID, studentID: UUID) async throws
}

extension StudentPlanRepository {
  public func shiftPlan(id: UUID, studentID: UUID) async throws -> PlanShiftResult {
    throw PlanShiftError.unavailable
  }

  public func cancelPlanShift(id: UUID, studentID: UUID) async throws {
    throw PlanShiftError.unavailable
  }
}
