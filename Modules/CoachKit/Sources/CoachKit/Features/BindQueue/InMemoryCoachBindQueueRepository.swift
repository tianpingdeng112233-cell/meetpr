import CoreModels
import Foundation
import RepositoryContracts

/// Demo/preview receive queue (spec 033 §与 031/032 的接口契约: the Demo
/// build seeds one pending request). Mirrors the backend transitions the UI
/// depends on: accept removes the row and mints a 7-day evaluation period
/// unless skipped; reject removes silently.
public actor InMemoryCoachBindQueueRepository: CoachBindQueueRepository {
  private var queue: [CoachBindRequestItem]
  private let coachId: UUID
  private let now: @Sendable () -> Date
  /// Accepted evaluation periods, observable by a paired
  /// InMemoryCoachEvaluationRepository through the shared store.
  private let evaluationStore: InMemoryEvaluationPeriodStore?

  public init(
    coachId: UUID,
    seed: [CoachBindRequestItem] = [],
    evaluationStore: InMemoryEvaluationPeriodStore? = nil,
    now: @escaping @Sendable () -> Date = { Date() }
  ) {
    self.coachId = coachId
    self.queue = seed
    self.evaluationStore = evaluationStore
    self.now = now
  }

  public func fetchQueue() async throws -> [CoachBindRequestItem] {
    queue.sorted { $0.submittedAt < $1.submittedAt }
  }

  public func accept(
    requestID: UUID,
    skipEvaluation: Bool,
    skipReason: String?
  ) async throws -> (request: BindRequestDecision, evaluation: EvaluationPeriod?) {
    guard let index = queue.firstIndex(where: { $0.id == requestID }) else {
      throw CoachBindQueueError.notFound
    }
    let item = queue[index]
    guard item.expiredAt > now() else {
      queue.remove(at: index)
      throw CoachBindQueueError.expired
    }
    queue.remove(at: index)

    var evaluation: EvaluationPeriod?
    if !skipEvaluation {
      let startedAt = now()
      evaluation = EvaluationPeriod(
        id: UUID(),
        studentId: item.studentId,
        coachId: coachId,
        bindRequestId: item.id,
        startedAt: startedAt,
        expectedEndAt: startedAt.addingTimeInterval(7 * 86_400),
        inProgress: true,
        overdue: false
      )
      if let evaluation, let evaluationStore {
        await evaluationStore.upsert(evaluation)
      }
    }

    let decision = BindRequestDecision(
      id: item.id,
      status: .accepted,
      skipEvaluation: skipEvaluation,
      skipReason: skipReason
    )
    return (request: decision, evaluation: evaluation)
  }

  public func reject(requestID: UUID) async throws {
    guard let index = queue.firstIndex(where: { $0.id == requestID }) else {
      throw CoachBindQueueError.notFound
    }
    queue.remove(at: index)
  }
}
