import Foundation
import Networking

/// Dependency bundle for the video upload feature, assembled once at app
/// startup and threaded down to TodayWorkoutView.
public struct VideoUploadServices: Sendable {
  public let manager: VideoUploadManager

  public init(manager: VideoUploadManager) {
    self.manager = manager
  }

  /// Demo/preview wiring: real AVFoundation export, loopback "uploads" that
  /// always succeed, nothing persisted across launches.
  public static func demo() -> VideoUploadServices {
    VideoUploadServices(
      manager: VideoUploadManager(
        service: LoopbackVideoUploadService(),
        exporter: AVFoundationVideoExporter(),
        repository: InMemoryVideoAttachmentRepository()
      )
    )
  }

  /// Production wiring against the backend `/uploads/*` pipeline.
  public static func backend(
    api: APIClient,
    session: any SessionStateReader
  ) -> VideoUploadServices {
    let manager = VideoUploadManager(
      service: BackendVideoUploadService(api: api, session: session),
      exporter: AVFoundationVideoExporter(),
      repository: BackendVideoAttachmentRepository(api: api, session: session),
      failureNotifier: UploadFailureNotifier(),
      enableNetworkMonitoring: true
    )
    return VideoUploadServices(manager: manager)
  }
}
