import CoreModels
import Foundation
import RepositoryContracts

/// Shared mutable store so the demo queue's accept can mint a period the
/// evaluation repository then serves (composition root wires both to one
/// instance).
public actor InMemoryEvaluationPeriodStore {
  private var periodsByStudent: [UUID: EvaluationPeriod]

  public init(seed: [EvaluationPeriod] = []) {
    periodsByStudent = Dictionary(
      seed.map { ($0.studentId, $0) },
      uniquingKeysWith: { _, new in new }
    )
  }

  func upsert(_ period: EvaluationPeriod) {
    periodsByStudent[period.studentId] = period
  }

  func period(studentID: UUID) -> EvaluationPeriod? {
    periodsByStudent[studentID]
  }

  func period(id: UUID) -> EvaluationPeriod? {
    periodsByStudent.values.first { $0.id == id }
  }
}

/// Demo/preview evaluation periods (spec 033 §9 demo seed contract). Mirrors
/// the backend semantics the UI depends on: complete is one-shot (409 →
/// `.alreadyCompleted`), overdue stays in progress.
public actor InMemoryCoachEvaluationRepository: EvaluationRepository {
  private let store: InMemoryEvaluationPeriodStore
  private let now: @Sendable () -> Date

  public init(
    store: InMemoryEvaluationPeriodStore = InMemoryEvaluationPeriodStore(),
    now: @escaping @Sendable () -> Date = { Date() }
  ) {
    self.store = store
    self.now = now
  }

  public func fetchEvaluation(studentID: UUID) async throws -> EvaluationPeriod? {
    await store.period(studentID: studentID)
  }

  public func fetchMyEvaluation() async throws -> EvaluationPeriod? {
    nil
  }

  public func completeEvaluation(id: UUID) async throws -> EvaluationPeriod {
    guard let existing = await store.period(id: id) else {
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
      completedAt: now(),
      completionType: "coach_completed",
      inProgress: false,
      overdue: false
    )
    await store.upsert(completed)
    return completed
  }
}

/// Demo/preview evaluation summaries. Mirrors the backend upsert semantics:
/// first save pins `firstSavedAt`, later saves only move `lastUpdatedAt`.
public actor InMemoryCoachEvaluationSummaryRepository: EvaluationSummaryRepository {
  private let coachId: UUID
  private var summariesByStudent: [UUID: EvaluationSummary]
  private let now: @Sendable () -> Date

  public init(
    coachId: UUID,
    seed: [EvaluationSummary] = [],
    now: @escaping @Sendable () -> Date = { Date() }
  ) {
    self.coachId = coachId
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
      coachId: coachId,
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

/// Demo/preview onboarding profile reads for CoachKit (the StudentKit
/// in-memory repository is unreachable across the Kit boundary).
public actor InMemoryCoachStudentProfileReader: OnboardingProfileReading {
  private let profilesByStudent: [UUID: OnboardingProfile]

  public init(profiles: [OnboardingProfile] = []) {
    profilesByStudent = Dictionary(
      profiles.map { ($0.userId, $0) },
      uniquingKeysWith: { _, new in new }
    )
  }

  public func fetchProfile(studentId: UUID) async throws -> OnboardingProfile? {
    profilesByStudent[studentId]
  }
}
