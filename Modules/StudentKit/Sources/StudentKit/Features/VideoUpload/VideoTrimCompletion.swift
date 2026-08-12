import Foundation

/// Platform-neutral completion state machine for a video trim session.
/// Guarantees the outcome handler fires at most once and that the temporary
/// source copy is cleaned up on every terminal path.
///
/// The claim is lock-guarded rather than main-actor isolated because `deinit`
/// runs wherever the last reference drops: an export finishing off the main
/// actor and a cover dismissal on it must contend for the same single shot.
final class VideoTrimCompletion: @unchecked Sendable {
  enum Outcome: Equatable {
    case saved(URL)
    case cancelled
    case failed
  }

  private let sourceURL: URL
  private let onOutcome: (Outcome) -> Void
  private let lock = NSLock()
  private var hasFinished = false

  init(sourceURL: URL, onOutcome: @escaping (Outcome) -> Void) {
    self.sourceURL = sourceURL
    self.onOutcome = onOutcome
  }

  deinit {
    if lock.withLock({ !hasFinished }) {
      try? FileManager.default.removeItem(at: sourceURL)
    }
  }

  @discardableResult
  func saved(editedVideoPath: String) -> Bool {
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

  /// Claims the single shot under the lock, then runs `body` outside it: the
  /// outcome handler touches SwiftUI state and must never run with a lock held.
  @discardableResult
  private func finish(_ body: () -> Void) -> Bool {
    let claimed = lock.withLock {
      guard !hasFinished else { return false }
      hasFinished = true
      return true
    }
    guard claimed else { return false }
    body()
    return true
  }
}

/// Stable owner for one presented trim flow. The same instance is held by the
/// cover and its UIKit coordinator so delegate completion, cover dismissal,
/// and representable dismantling all converge on one idempotent cleanup path.
final class VideoTrimSession: Identifiable {
  let id = UUID()
  let sourceURL: URL
  let maxDurationSeconds: TimeInterval

  private let completion: VideoTrimCompletion

  init(
    sourceURL: URL,
    maxDurationSeconds: TimeInterval,
    onSave: @escaping (URL) -> Void,
    onCancel: @escaping () -> Void,
    onFailure: @escaping () -> Void
  ) {
    self.sourceURL = sourceURL
    self.maxDurationSeconds = maxDurationSeconds
    completion = VideoTrimCompletion(sourceURL: sourceURL) { outcome in
      switch outcome {
      case .saved(let editedURL): onSave(editedURL)
      case .cancelled: onCancel()
      case .failed: onFailure()
      }
    }
  }

  @discardableResult
  func saved(editedVideoPath: String) -> Bool {
    completion.saved(editedVideoPath: editedVideoPath)
  }

  func cancelled() {
    completion.cancelled()
  }

  func failed() {
    completion.failed()
  }

  /// Main-actor isolated so the outcome handlers it fires mutate SwiftUI state
  /// on the main actor; the export itself suspends off it.
  @MainActor
  func exportTrim(
    selection: VideoTrimSelection,
    using exporter: any VideoTrimExporting = PassthroughVideoTrimExporter()
  ) async {
    do {
      let outputURL = try await exporter.export(sourceURL: sourceURL, selection: selection)
      // An export that finishes anyway after cancellation must not resurrect a
      // torn-down cover: treat cancellation as losing the claim outright, since
      // AVAssetExportSession can complete before it observes cancelExport().
      guard !Task.isCancelled else {
        try? FileManager.default.removeItem(at: outputURL)
        return
      }
      // Dismissal may have claimed the session while the export ran; the
      // orphaned output is ours to delete in that case.
      if !saved(editedVideoPath: outputURL.path) {
        try? FileManager.default.removeItem(at: outputURL)
      }
    } catch is CancellationError {
      // Teardown owns the outcome: a cancelled export means the cover is going
      // away, and reporting a failure here would race that with a false alarm.
    } catch {
      failed()
    }
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
