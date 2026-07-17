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
