import CoreModels
import Foundation
import RepositoryContracts

/// Races the completion response against its deadline without waiting for a
/// repository that ignores cancellation. Only the winning result reaches the VM.
@MainActor
final class WorkoutCompletionRequest {
  private var continuation: CheckedContinuation<PlanDayCompletion, any Error>?
  private var request: Task<Void, Never>?
  private var timeout: Task<Void, Never>?

  func complete(
    dayID: UUID,
    studentID: UUID,
    plans: any StudentPlanRepository,
    sleep: @escaping @MainActor @Sendable () async -> Void
  ) async throws -> PlanDayCompletion {
    try await withCheckedThrowingContinuation { continuation in
      self.continuation = continuation
      request = Task {
        do {
          let completion = try await plans.completeDay(id: dayID, studentID: studentID)
          finish(.success(completion))
        } catch {
          finish(.failure(error))
        }
      }
      timeout = Task { await waitForTimeout(sleep: sleep) }
    }
  }

  private func waitForTimeout(
    sleep: @escaping @MainActor @Sendable () async -> Void
  ) async {
    await sleep()
    guard !Task.isCancelled else { return }
    finish(.failure(URLError(.timedOut)))
  }

  private func finish(_ result: Result<PlanDayCompletion, any Error>) {
    guard let continuation else { return }
    self.continuation = nil
    request?.cancel()
    timeout?.cancel()
    request = nil
    timeout = nil
    continuation.resume(with: result)
  }
}
