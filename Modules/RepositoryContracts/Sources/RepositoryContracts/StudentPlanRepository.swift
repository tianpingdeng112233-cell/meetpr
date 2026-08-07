import CoreModels
import Foundation

public enum PlanDayCompletionError: Error, Equatable, Sendable {
  case planNotActive
  case notPlanStudent
  case notLatestCompletion
  case undoWindowPassed
  case unavailable

  public init?(machineCode: String?) {
    switch machineCode {
    case "PLAN_NOT_ACTIVE": self = .planNotActive
    case "NOT_PLAN_STUDENT": self = .notPlanStudent
    case "NOT_LATEST_COMPLETION": self = .notLatestCompletion
    case "UNDO_WINDOW_PASSED": self = .undoWindowPassed
    default: return nil
    }
  }

  public var localizedMessage: String {
    switch self {
    case .notLatestCompletion: "只能撤销最近完成的一天"
    case .undoWindowPassed: "只能在当天撤销"
    case .planNotActive: "这份计划已不是当前计划"
    case .notPlanStudent: "无法修改这一天的完成状态"
    case .unavailable: "暂时无法完成操作，请稍后重试。"
    }
  }
}

public struct PlanDayCompletion: Equatable, Sendable {
  public let id: UUID
  public let dayID: UUID
  public let studentID: UUID
  public let source: String
  public let completedAt: Date

  public init(id: UUID, dayID: UUID, studentID: UUID, source: String, completedAt: Date) {
    self.id = id
    self.dayID = dayID
    self.studentID = studentID
    self.source = source
    self.completedAt = completedAt
  }
}

/// Access to the student's current published plan and sequence completion mutations.
/// `studentID` is the current user's; the UI layer reads it from Session and passes it in.
public protocol StudentPlanRepository: Sendable {
  func fetchCurrentPlan(studentID: UUID) async throws -> StudentPlanView?
  /// Bypasses stale-while-revalidate cache when completion may have changed.
  func refreshCurrentPlan(studentID: UUID) async throws -> StudentPlanView?
  func fetchDay(studentID: UUID, dayID: UUID) async throws -> StudentPlanDay?
  /// All days in the current cycle; the UI groups them by week.
  func fetchCycleDays(studentID: UUID) async throws -> [StudentPlanDay]
  @discardableResult
  func completeDay(id: UUID, studentID: UUID) async throws -> PlanDayCompletion
  func undoDayCompletion(id: UUID, studentID: UUID) async throws
}

extension StudentPlanRepository {
  public func refreshCurrentPlan(studentID: UUID) async throws -> StudentPlanView? {
    try await fetchCurrentPlan(studentID: studentID)
  }

  public func fetchDay(studentID: UUID, dayID: UUID) async throws -> StudentPlanDay? {
    try await fetchCurrentPlan(studentID: studentID)?.days.first { $0.id == dayID }
  }

  /// Compatibility lookup for non-sequence consumers. Student navigation must use `dayID`.
  public func fetchDay(studentID: UUID, date: Date) async throws -> StudentPlanDay? {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? calendar.timeZone
    return try await fetchCurrentPlan(studentID: studentID)?.days.first {
      calendar.isDate($0.scheduledDate, inSameDayAs: date)
    }
  }

  @discardableResult
  public func completeDay(id: UUID, studentID: UUID) async throws -> PlanDayCompletion {
    throw PlanDayCompletionError.unavailable
  }

  public func undoDayCompletion(id: UUID, studentID: UUID) async throws {
    throw PlanDayCompletionError.unavailable
  }
}
