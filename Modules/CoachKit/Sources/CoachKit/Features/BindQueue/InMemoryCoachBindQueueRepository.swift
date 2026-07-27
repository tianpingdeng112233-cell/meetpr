import CoreModels
import Foundation
import RepositoryContracts

/// Demo/preview receive queue (spec 033 §与 031/032 的接口契约: the Demo
/// build seeds one pending request). Mirrors the backend transitions the UI
/// depends on: accept and reject both remove the row.
public actor InMemoryCoachBindQueueRepository: CoachBindQueueRepository {
  private var queue: [CoachBindRequestItem]
  private let now: @Sendable () -> Date

  public init(
    seed: [CoachBindRequestItem] = [],
    now: @escaping @Sendable () -> Date = { Date() }
  ) {
    self.queue = seed
    self.now = now
  }

  public func fetchQueue() async throws -> [CoachBindRequestItem] {
    queue.sorted { $0.submittedAt < $1.submittedAt }
  }

  public func accept(requestID: UUID) async throws {
    guard let index = queue.firstIndex(where: { $0.id == requestID }) else {
      throw CoachBindQueueError.notFound
    }
    let item = queue[index]
    guard item.expiredAt > now() else {
      queue.remove(at: index)
      throw CoachBindQueueError.expired
    }
    queue.remove(at: index)
  }

  public func reject(requestID: UUID) async throws {
    guard let index = queue.firstIndex(where: { $0.id == requestID }) else {
      throw CoachBindQueueError.notFound
    }
    queue.remove(at: index)
  }
}
