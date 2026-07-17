import Foundation

/// Platform-neutral completion state machine for a video trim session.
/// Guarantees the outcome handler fires at most once and that the temporary
/// source copy is cleaned up on every terminal path.
final class VideoTrimCompletion {
  enum Outcome: Equatable {
    case saved(URL)
    case cancelled
    case failed
  }

  private let sourceURL: URL
  private let onOutcome: (Outcome) -> Void
  private var hasFinished = false

  init(sourceURL: URL, onOutcome: @escaping (Outcome) -> Void) {
    self.sourceURL = sourceURL
    self.onOutcome = onOutcome
  }

  func saved(editedVideoPath: String) {
    finish {
      let editedURL = URL(fileURLWithPath: editedVideoPath)
      if editedURL != sourceURL {
        try? FileManager.default.removeItem(at: sourceURL)
      }
      onOutcome(.saved(editedURL))
    }
  }

  func cancelled() {
    finish {
      try? FileManager.default.removeItem(at: sourceURL)
      onOutcome(.cancelled)
    }
  }

  func failed() {
    finish {
      try? FileManager.default.removeItem(at: sourceURL)
      onOutcome(.failed)
    }
  }

  private func finish(_ body: () -> Void) {
    guard !hasFinished else { return }
    hasFinished = true
    body()
  }
}

/// Fires a body at most once; guards UIKit delegate callbacks that the system
/// may deliver repeatedly.
final class SingleShot {
  private var hasFired = false

  func run(_ body: () -> Void) {
    guard !hasFired else { return }
    hasFired = true
    body()
  }
}
