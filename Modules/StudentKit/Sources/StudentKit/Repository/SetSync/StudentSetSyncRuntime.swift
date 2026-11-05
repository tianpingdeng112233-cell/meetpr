import Foundation

/// One account queue is shared by SwiftUI and URLSession's UI-less cold launch.
@MainActor final class StudentSetSyncRuntime {
  typealias Factory = @MainActor (UUID, VideoUploadManager) throws -> StudentSetSyncSession
  private let identity: @Sendable () async -> UUID?
  private let prepare: @Sendable () async -> Void
  private let factory: Factory
  private var current: StudentSetSyncSession?

  init(
    identity: @escaping @Sendable () async -> UUID?,
    prepare: @escaping @Sendable () async -> Void = {}, factory: @escaping Factory
  ) {
    self.identity = identity
    self.prepare = prepare
    self.factory = factory
  }

  func session(
    studentID: UUID, videos: VideoUploadManager,
    onLogout: @escaping @MainActor () async -> Void
  ) throws -> StudentSetSyncSession {
    if current?.queue.studentID != studentID {
      current?.stop()
      current = try factory(studentID, videos)
      current?.queue.videoCompletion?.isCurrentAccount = { [identity] in
        await identity() == studentID
      }
    }
    guard let current else { throw CancellationError() }
    current.onLogout = onLogout
    return current
  }

  func recover(videos: VideoUploadManager) async {
    await prepare()
    guard let studentID = await identity() else {
      current?.stop()
      return
    }
    do {
      let session = try session(
        studentID: studentID, videos: videos,
        onLogout: current?.onLogout ?? {})
      guard await identity() == studentID else {
        session.stop()
        return
      }
      await videos.registerCompletionAccount(studentID)
      session.start(network: UploadNetworkMonitor())
      await session.queue.videoCompletion?.refresh()
    } catch {
      // Leave the durable queue for the next authenticated wake.
    }
  }
}
