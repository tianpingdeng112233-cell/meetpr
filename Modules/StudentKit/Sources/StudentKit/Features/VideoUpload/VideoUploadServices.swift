import Foundation
import Networking

/// Dependency bundle for the video upload feature, assembled once at app
/// startup and threaded down to TodayWorkoutView.
public struct VideoUploadServices: Sendable {
  var completionRuntime: StudentSetSyncRuntime?
  public let manager: VideoUploadManager
  public let replayRepository: (any StudentReplayVideoRepository)?

  public init(
    manager: VideoUploadManager,
    replayRepository: (any StudentReplayVideoRepository)? = nil
  ) {
    self.manager = manager
    self.replayRepository = replayRepository
  }

  /// Demo/preview wiring: real AVFoundation export, loopback "uploads" that
  /// always succeed, nothing persisted across launches.
  public static func demo() -> VideoUploadServices {
    if let scenario = VideoDeliveryDemoScenario.services() { return scenario }
    return VideoUploadServices(
      manager: VideoUploadManager(
        service: LoopbackVideoUploadService(),
        exporter: AVFoundationVideoExporter(),
        repository: InMemoryVideoAttachmentRepository(seed: AccessoryDemoScenario.videoAttachments)
      ),
      replayRepository: CompletedVideoDemoRepository()
    )
  }

  /// Production wiring against the backend `/uploads/*` pipeline.
  @MainActor public static func backend(
    api: APIClient,
    session: any SessionStateReader,
    prepareSession: @escaping @Sendable () async -> Void = {}
  ) -> VideoUploadServices {
    let manager = VideoUploadManager(
      service: BackendVideoUploadService(api: api, session: session),
      exporter: AVFoundationVideoExporter(),
      repository: BackendVideoAttachmentRepository(api: api, session: session),
      failureNotifier: UploadFailureNotifier(),
      enableNetworkMonitoring: true
    )
    let runtime = StudentSetSyncRuntime(
      identity: {
        guard let user = try? await session.currentUser(), user.role == .coachedStudent else {
          return nil
        }
        return user.id
      }, prepare: prepareSession,
      factory: { studentID, videos in
        try StudentSetSyncSession.live(
          studentID: studentID,
          plans: BackendStudentPlanRepository(api: api, session: session),
          logs: BackendStudentTrainingLogRepository(api: api, session: session),
          videos: videos, onLogout: {})
      })
    var services = VideoUploadServices(
      manager: manager,
      replayRepository: BackendStudentReplayVideoRepository(api: api, session: session))
    services.completionRuntime = runtime
    Task {
      // Register before reading any restored URLSession event; no View.task is required.
      await manager.installCompletionRecovery { [weak runtime] manager in
        await runtime?.recover(videos: manager)
      }
      await runtime.recover(videos: manager)
      await manager.activateBackgroundHandling()
    }
    return services
  }
}
