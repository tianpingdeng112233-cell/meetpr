import CoreModels
import Foundation
import RepositoryContracts

public actor EmptyStudentPlanRepository: StudentPlanRepository {
  public init() {}

  public func fetchCurrentPlan(studentID: UUID) async throws -> StudentPlanView? {
    nil
  }

  public func fetchDay(studentID: UUID, date: Date) async throws -> StudentPlanDay? {
    nil
  }

  public func fetchCycleDays(studentID: UUID) async throws -> [StudentPlanDay] {
    []
  }
}

public actor EmptyStudentTrainingLogRepository: StudentTrainingLogRepository {
  public init() {}

  @discardableResult
  public func recordSet(_ log: StudentSetLog) async throws -> StudentSetLog { log }

  public func fetchLogs(
    studentID: UUID,
    in dateRange: ClosedRange<Date>
  ) async throws -> [StudentSetLog] {
    []
  }

  public func fetchLogsForExercise(
    studentID: UUID,
    planExerciseID: UUID
  ) async throws -> [StudentSetLog] {
    []
  }
}

public actor EmptyStudentFeedbackRepository: StudentFeedbackRepository {
  public init() {}

  public func fetchInbox(studentID: UUID) async throws -> [CoachFeedback] {
    []
  }

  public func postFeedback(
    studentID: UUID,
    dayDate: Date?,
    planExerciseID: UUID?,
    text: String
  ) async throws -> CoachFeedback {
    CoachFeedback(
      id: UUID(),
      coachID: UUID(),
      studentID: studentID,
      dayDate: dayDate,
      planExerciseID: planExerciseID,
      text: text,
      postedAt: Date(),
      readAt: nil
    )
  }

  public func markRead(feedbackID: UUID) async throws {}
}

/// Default readiness source for previews and repository-less init paths: the
/// coach overview row renders the "not filed today" state.
public actor EmptyReadinessRepository: ReadinessRepository {
  public init() {}

  public func submit(_ checkin: ReadinessCheckin) async throws {}

  public func fetchCheckin(
    studentId: UUID,
    checkinDate: String
  ) async throws -> ReadinessCheckin? {
    nil
  }
}
