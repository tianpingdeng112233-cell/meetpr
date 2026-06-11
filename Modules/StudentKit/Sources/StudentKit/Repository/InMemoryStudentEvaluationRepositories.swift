import CoreModels
import Foundation
import RepositoryContracts

/// Demo/preview evaluation periods, student perspective.
public actor InMemoryStudentEvaluationRepository: EvaluationRepository {
  private var period: EvaluationPeriod?

  public init(seed: EvaluationPeriod? = nil) {
    period = seed
  }

  public func fetchEvaluation(studentID: UUID) async throws -> EvaluationPeriod? {
    guard period?.studentId == studentID else { return nil }
    return period
  }

  public func fetchMyEvaluation() async throws -> EvaluationPeriod? {
    period
  }

  public func completeEvaluation(id: UUID) async throws -> EvaluationPeriod {
    guard let existing = period, existing.id == id else {
      throw EvaluationError.notFound
    }
    guard existing.completedAt == nil else {
      throw EvaluationError.alreadyCompleted
    }
    let completed = EvaluationPeriod(
      id: existing.id,
      studentId: existing.studentId,
      coachId: existing.coachId,
      bindRequestId: existing.bindRequestId,
      startedAt: existing.startedAt,
      expectedEndAt: existing.expectedEndAt,
      completedAt: Date(),
      completionType: "coach_completed",
      inProgress: false,
      overdue: false
    )
    period = completed
    return completed
  }
}

/// Demo/preview evaluation summaries, student perspective (read-mostly).
public actor InMemoryEvaluationSummaryRepository: EvaluationSummaryRepository {
  private var summariesByStudent: [UUID: EvaluationSummary]
  private let now: @Sendable () -> Date

  public init(
    seed: [EvaluationSummary] = [],
    now: @escaping @Sendable () -> Date = { Date() }
  ) {
    summariesByStudent = Dictionary(
      seed.map { ($0.studentId, $0) },
      uniquingKeysWith: { _, new in new }
    )
    self.now = now
  }

  public func fetchSummary(studentID: UUID) async throws -> EvaluationSummary? {
    summariesByStudent[studentID]
  }

  public func putSummary(
    studentID: UUID,
    overallAssessment: String,
    trainingPlan: String,
    wordsToStudent: String?,
    notifyStudent: Bool
  ) async throws -> EvaluationSummary {
    let timestamp = now()
    let existing = summariesByStudent[studentID]
    let summary = EvaluationSummary(
      id: existing?.id ?? UUID(),
      studentId: studentID,
      coachId: existing?.coachId ?? UUID(),
      evaluationPeriodId: existing?.evaluationPeriodId,
      overallAssessment: overallAssessment,
      trainingPlan: trainingPlan,
      wordsToStudent: wordsToStudent,
      firstSavedAt: existing?.firstSavedAt ?? timestamp,
      lastUpdatedAt: timestamp,
      isActive: true
    )
    summariesByStudent[studentID] = summary
    return summary
  }
}
