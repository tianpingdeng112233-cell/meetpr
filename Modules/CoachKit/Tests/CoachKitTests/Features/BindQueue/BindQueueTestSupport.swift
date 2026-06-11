import CoreModels
import Foundation
import RepositoryContracts

@testable import CoachKit

enum BindQueueFixtures {
  static let now = Date(timeIntervalSince1970: 1_781_000_000)
  static let coachID = UUID(uuidString: "03300000-0000-0000-0000-000000000001")!
  static let studentID = UUID(uuidString: "03300000-0000-0000-0000-000000000101")!
  static let requestID = UUID(uuidString: "03300000-0000-0000-0000-000000000201")!

  static func item(
    id: UUID = requestID,
    studentId: UUID = studentID,
    displayName: String = "张三",
    submittedAt: Date = now.addingTimeInterval(-2 * 3_600),
    expiredAt: Date = now.addingTimeInterval(5 * 86_400),
    onboarding: CoachBindRequestOnboardingSummary = onboarding()
  ) -> CoachBindRequestItem {
    CoachBindRequestItem(
      id: id,
      studentId: studentId,
      displayName: displayName,
      submittedAt: submittedAt,
      expiredAt: expiredAt,
      onboarding: onboarding
    )
  }

  static func onboarding(completed: Bool = true) -> CoachBindRequestOnboardingSummary {
    guard completed else {
      return CoachBindRequestOnboardingSummary(completed: false)
    }
    return CoachBindRequestOnboardingSummary(
      completed: true,
      gender: .male,
      birthDate: "2001-03-15",
      weightKg: 83,
      trainingYears: 3,
      squat1RMKg: 180,
      bench1RMKg: Decimal(string: "92.50")!,
      deadlift1RMKg: 220,
      muscleGroupsToStrengthen: [.quad, .hamstring, .shoulder],
      gymTier: .commercial,
      isCompeting: true,
      competitionDate: "2026-07-25",
      noteToCoach: "想突破 200kg 深蹲",
      uploadCount: 4
    )
  }

  static func evaluation(
    studentId: UUID = studentID,
    startedAt: Date = now.addingTimeInterval(-2 * 86_400),
    expectedEndAt: Date = now.addingTimeInterval(5 * 86_400),
    completedAt: Date? = nil
  ) -> EvaluationPeriod {
    EvaluationPeriod(
      id: UUID(uuidString: "03300000-0000-0000-0000-000000000301")!,
      studentId: studentId,
      coachId: coachID,
      bindRequestId: requestID,
      startedAt: startedAt,
      expectedEndAt: expectedEndAt,
      completedAt: completedAt,
      completionType: completedAt == nil ? nil : "coach_completed",
      inProgress: completedAt == nil,
      overdue: false
    )
  }
}

struct RecordedAccept: Equatable {
  let id: UUID
  let skip: Bool
  let reason: String?
}

/// Scripted queue repository: counts calls, throws per-action errors.
actor StubBindQueueRepository: CoachBindQueueRepository {
  var queue: [CoachBindRequestItem]
  var acceptError: Error?
  var rejectError: Error?
  private(set) var acceptedRequests: [RecordedAccept] = []
  private(set) var rejectedRequestIDs: [UUID] = []
  private(set) var fetchCount = 0
  private let evaluationOnAccept: EvaluationPeriod?

  init(
    queue: [CoachBindRequestItem] = [BindQueueFixtures.item()],
    acceptError: Error? = nil,
    rejectError: Error? = nil,
    evaluationOnAccept: EvaluationPeriod? = nil
  ) {
    self.queue = queue
    self.acceptError = acceptError
    self.rejectError = rejectError
    self.evaluationOnAccept = evaluationOnAccept
  }

  func fetchQueue() async throws -> [CoachBindRequestItem] {
    fetchCount += 1
    return queue
  }

  func accept(
    requestID: UUID,
    skipEvaluation: Bool,
    skipReason: String?
  ) async throws -> (request: BindRequestDecision, evaluation: EvaluationPeriod?) {
    if let acceptError { throw acceptError }
    acceptedRequests.append(
      RecordedAccept(id: requestID, skip: skipEvaluation, reason: skipReason))
    queue.removeAll { $0.id == requestID }
    let decision = BindRequestDecision(
      id: requestID, status: .accepted, skipEvaluation: skipEvaluation, skipReason: skipReason)
    return (request: decision, evaluation: skipEvaluation ? nil : evaluationOnAccept)
  }

  func reject(requestID: UUID) async throws {
    if let rejectError { throw rejectError }
    rejectedRequestIDs.append(requestID)
    queue.removeAll { $0.id == requestID }
  }
}

actor StubEvaluationRepository: EvaluationRepository {
  var evaluationsByStudent: [UUID: EvaluationPeriod]
  var fetchError: Error?
  var completeError: Error?
  private(set) var completedIDs: [UUID] = []

  init(
    evaluationsByStudent: [UUID: EvaluationPeriod] = [:],
    fetchError: Error? = nil,
    completeError: Error? = nil
  ) {
    self.evaluationsByStudent = evaluationsByStudent
    self.fetchError = fetchError
    self.completeError = completeError
  }

  func fetchEvaluation(studentID: UUID) async throws -> EvaluationPeriod? {
    if let fetchError { throw fetchError }
    return evaluationsByStudent[studentID]
  }

  func fetchMyEvaluation() async throws -> EvaluationPeriod? {
    if let fetchError { throw fetchError }
    return evaluationsByStudent.values.first
  }

  func completeEvaluation(id: UUID) async throws -> EvaluationPeriod {
    if let completeError { throw completeError }
    guard let existing = evaluationsByStudent.values.first(where: { $0.id == id }) else {
      throw EvaluationError.notFound
    }
    completedIDs.append(id)
    let completed = EvaluationPeriod(
      id: existing.id,
      studentId: existing.studentId,
      coachId: existing.coachId,
      bindRequestId: existing.bindRequestId,
      startedAt: existing.startedAt,
      expectedEndAt: existing.expectedEndAt,
      completedAt: BindQueueFixtures.now,
      completionType: "coach_completed",
      inProgress: false,
      overdue: false
    )
    evaluationsByStudent[existing.studentId] = completed
    return completed
  }
}

struct RecordedSummaryPut: Equatable {
  let studentID: UUID
  let notify: Bool
  let words: String?
}

actor StubEvaluationSummaryRepository: EvaluationSummaryRepository {
  var summariesByStudent: [UUID: EvaluationSummary]
  var putError: Error?
  private(set) var putRequests: [RecordedSummaryPut] = []

  init(summariesByStudent: [UUID: EvaluationSummary] = [:], putError: Error? = nil) {
    self.summariesByStudent = summariesByStudent
    self.putError = putError
  }

  func fetchSummary(studentID: UUID) async throws -> EvaluationSummary? {
    summariesByStudent[studentID]
  }

  func putSummary(
    studentID: UUID,
    overallAssessment: String,
    trainingPlan: String,
    wordsToStudent: String?,
    notifyStudent: Bool
  ) async throws -> EvaluationSummary {
    if let putError { throw putError }
    putRequests.append(
      RecordedSummaryPut(studentID: studentID, notify: notifyStudent, words: wordsToStudent))
    let existing = summariesByStudent[studentID]
    let summary = EvaluationSummary(
      id: existing?.id ?? UUID(),
      studentId: studentID,
      coachId: BindQueueFixtures.coachID,
      evaluationPeriodId: existing?.evaluationPeriodId,
      overallAssessment: overallAssessment,
      trainingPlan: trainingPlan,
      wordsToStudent: wordsToStudent,
      firstSavedAt: existing?.firstSavedAt ?? BindQueueFixtures.now,
      lastUpdatedAt: BindQueueFixtures.now,
      isActive: true
    )
    summariesByStudent[studentID] = summary
    return summary
  }
}

actor StubProfileReader: OnboardingProfileReading {
  var profile: OnboardingProfile?
  var error: Error?

  init(profile: OnboardingProfile? = nil, error: Error? = nil) {
    self.profile = profile
    self.error = error
  }

  func fetchProfile(studentId: UUID) async throws -> OnboardingProfile? {
    if let error { throw error }
    return profile
  }
}
