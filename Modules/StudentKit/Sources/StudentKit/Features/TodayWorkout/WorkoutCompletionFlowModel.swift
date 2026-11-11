import Foundation
import Observation

enum WorkoutCompletionFlowPhase: String, Identifiable, Sendable {
  case celebration
  case review

  var id: String { rawValue }
}

@MainActor
@Observable
final class WorkoutCompletionFlowModel {
  private(set) var phase: WorkoutCompletionFlowPhase
  private(set) var didFinish = false

  private(set) var isAutoClosePending = true

  init(initialPhase: WorkoutCompletionFlowPhase) {
    phase = initialPhase
    isAutoClosePending = initialPhase == .celebration
  }

  func autoClose(
    sleep: @MainActor (Duration) async throws -> Void = { try await Task.sleep(for: $0) },
    onFinish: () -> Void
  ) async {
    guard isAutoClosePending, phase == .celebration, !didFinish else { return }
    do {
      try await sleep(.seconds(5))
      try Task.checkCancellation()
    } catch {
      return
    }
    guard isAutoClosePending else { return }
    finish(onFinish: onFinish)
  }

  func openReview() {
    touch()
    phase = .review
  }

  func touch() {
    isAutoClosePending = false
  }

  func finish(onFinish: () -> Void) {
    guard !didFinish else { return }
    isAutoClosePending = false
    didFinish = true
    onFinish()
  }
}
