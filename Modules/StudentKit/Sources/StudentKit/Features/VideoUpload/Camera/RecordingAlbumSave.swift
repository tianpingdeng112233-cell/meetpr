import ChatUI
import Foundation

#if os(iOS)
  import UIKit
#endif

enum RecordingAlbumSource: Sendable {
  case file(URL)
  /// A memory mapping keeps the inode alive even after upload unlinks its path.
  case mappedOriginal(Data, filename: String)
}

/// One job per accepted recording. Upload can move/delete its URL immediately.
@MainActor
final class RecordingAlbumSave {
  typealias Export = @MainActor (URL, VideoBadgeInfo) async throws -> URL
  typealias Save = @MainActor (RecordingAlbumSource) async throws -> Void

  private let backgroundGrace: Duration
  private let link: (URL, URL) throws -> Void
  private var backgroundTimer: Task<Void, Never>?
  private let export: Export
  private let save: Save
  private var albumSource: URL?
  private var exportTask: Task<URL, Error>?
  private var photoTask: Task<Void, Error>?
  #if os(iOS)
    private var lifecycleObservers: [NSObjectProtocol] = []
    private var backgroundID = UIBackgroundTaskIdentifier.invalid
  #endif

  init(
    backgroundGrace: Duration = .seconds(10),
    link: @escaping (URL, URL) throws -> Void = FileManager.default.linkItem(at:to:),
    export: @escaping Export, save: @escaping Save
  ) {
    self.backgroundGrace = backgroundGrace
    self.link = link
    self.export = export
    self.save = save
  }

  func use(
    original: URL, badge: VideoBadgeInfo?, saveToAlbum: Bool, onPicked: (URL) -> Void
  ) -> Task<Void, Error>? {
    defer { onPicked(original) }
    guard saveToAlbum else { return nil }
    // Hard-link before handoff. The recording and its link share file data.
    let link = URL.temporaryDirectory.appending(path: UUID().uuidString)
      .appendingPathExtension(original.pathExtension)
    beginBackgroundTask()
    do {
      try self.link(original, link)
    } catch {
      let snapshot = Result { try Data(contentsOf: original, options: .alwaysMapped) }
      return Task {
        defer { endBackgroundTask() }
        try await save(.mappedOriginal(try snapshot.get(), filename: original.lastPathComponent))
      }
    }
    albumSource = link
    if let badge, badge.hasContent {
      exportTask = Task {
        try Task.checkCancellation()
        return try await export(link, badge)
      }
      observeAppLifecycle()
    }
    return Task {
      defer {
        try? FileManager.default.removeItem(at: link)
        albumSource = nil
        exportTask = nil
        photoTask = nil
        endBackgroundTask()
      }
      let output = await withTaskCancellationHandler {
        if Task.isCancelled { expire() }
        return try? await exportTask?.value
      } onCancel: {
        Task { @MainActor in self.expire() }
      }
      defer {
        if let output { try? FileManager.default.removeItem(at: output) }
      }
      startPhotoSave(Task.isCancelled ? link : output ?? link, original: link)
      try await photoTask?.value
    }
  }

  func enteredBackground(timeRemaining: TimeInterval? = nil) {
    guard exportTask != nil, photoTask == nil, backgroundTimer == nil else { return }
    // Especially late transitions can have less than the normal allowance.
    var delay = backgroundGrace
    if let remaining = timeRemaining, remaining < Double(Int64.max) {
      delay = min(delay, .seconds(max(0, remaining) / 2))
    }
    backgroundTimer = Task {
      do {
        try await Task.sleep(for: delay)
      } catch {
        return
      }
      expire()
    }
  }

  private func cancelBackgroundTimer() {
    backgroundTimer?.cancel()
    backgroundTimer = nil
  }

  private func observeAppLifecycle() {
    #if os(iOS)
      let center = NotificationCenter.default
      lifecycleObservers = [
        center.addObserver(
          forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main
        ) { [weak self] _ in
          MainActor.assumeIsolated {
            self?.enteredBackground(timeRemaining: UIApplication.shared.backgroundTimeRemaining)
          }
        },
        center.addObserver(
          forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main
        ) { [weak self] _ in
          MainActor.assumeIsolated { self?.cancelBackgroundTimer() }
        },
      ]
      if UIApplication.shared.applicationState == .background {
        enteredBackground(timeRemaining: UIApplication.shared.backgroundTimeRemaining)
      }
    #endif
  }

  /// Begin fallback immediately, even if AVFoundation is still unwinding.
  /// An in-flight Photos transaction already owns the single album insertion.
  func expire() {
    guard let albumSource else { return }
    exportTask?.cancel()
    startPhotoSave(albumSource, original: albumSource)
  }

  private func startPhotoSave(_ url: URL, original: URL) {
    guard photoTask == nil else { return }
    cancelBackgroundTimer()
    photoTask = Task {
      defer { endBackgroundTask() }
      do {
        try await save(.file(url))
      } catch  where url != original {
        try await save(.file(original))
      }
    }
  }

  private func beginBackgroundTask() {
    #if os(iOS)
      backgroundID = UIApplication.shared.beginBackgroundTask(withName: "RecordingAlbumSave") {
        self.expire()
        // Release the expired assertion before returning to UIKit. The photo
        // task retains its source across suspension until Photos finishes.
        self.endBackgroundTask()
      }
    #endif
  }

  private func endBackgroundTask() {
    #if os(iOS)
      lifecycleObservers.forEach(NotificationCenter.default.removeObserver)
      lifecycleObservers.removeAll()
      guard backgroundID != .invalid else { return }
      UIApplication.shared.endBackgroundTask(backgroundID)
      backgroundID = .invalid
    #endif
  }
}

#if os(iOS)
  extension RecordingAlbumSave {
    static func accept(
      _ url: URL, badge: VideoBadgeInfo?, saveToAlbum: Bool,
      onPicked: (URL) -> Void, onFailure: @escaping () -> Void
    ) {
      let job = RecordingAlbumSave(
        export: VideoBadgeExporter().export,
        save: { source in
          guard await VideoLibrarySaver.save(source) else { throw CocoaError(.fileWriteUnknown) }
        })
      if let saving = job.use(
        original: url, badge: badge, saveToAlbum: saveToAlbum, onPicked: onPicked)
      {
        Task {
          do { try await saving.value } catch { onFailure() }
        }
      }
    }
  }
#endif
