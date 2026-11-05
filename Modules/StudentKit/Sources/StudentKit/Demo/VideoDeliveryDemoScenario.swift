import CoreModels
import Foundation
import Networking
import UserNotifications

/// Opt-in spec 101 evidence: production disk store, manager and retry scheduler;
/// only the transport/playback server is replaced with the bundled demo clip.
enum VideoDeliveryDemoScenario {
  static var enabled: Bool { has("video") }
  static var missing: Bool { has("missing") }

  private static let sharedServices = makeServices()

  static func services() -> VideoUploadServices? { sharedServices }

  private static func makeServices() -> VideoUploadServices? {
    guard enabled else { return nil }
    #if os(iOS)
      if has("photos"),
        let clip = Bundle.main.url(forResource: "coach-demo-video", withExtension: "mp4")
      {
        Task { _ = await VideoLibrarySaver.save(clip) }
      }
    #endif
    let directory = URL.documentsDirectory.appending(
      path: "spec101-video", directoryHint: .isDirectory)
    let storeFile = directory.appending(path: "attachments.json")
    if has("reset") { try? FileManager.default.removeItem(at: directory) }
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    if !FileManager.default.fileExists(atPath: storeFile.path) {
      let records = seed(directory: directory)
      let encoder = JSONEncoder()
      encoder.dateEncodingStrategy = .iso8601
      print(
        "Spec101 seeded \(records.count) attachments; missing=\(missing)",
        "notification=\(has("notification"))"
      )
      if let data = try? encoder.encode(records) {
        try? data.write(to: storeFile, options: .atomic)
      }
    }
    let api = APIClient(environment: ["MEETPR_API_BASE_URL": "https://spec101.invalid"]) { _ in
      guard let clip = Bundle.main.url(forResource: "coach-demo-video", withExtension: "mp4") else {
        return APIResponse(data: Data(), statusCode: 404)
      }
      let body = AttachmentURLResponseDTO(url: clip.absoluteString, expiresIn: 3600)
      return APIResponse(data: try JSONEncoder().encode(body), statusCode: 200)
    }
    if has("notification") {
      UNUserNotificationCenter.current().delegate = VideoDeliveryDemoNotifications.shared
    }
    return VideoUploadServices(
      manager: VideoUploadManager(
        service: LoopbackVideoUploadService(), exporter: AVFoundationVideoExporter(),
        repository: BackendVideoAttachmentRepository(
          api: api, session: VideoDeliveryDemoSession(), directory: directory),
        filesDirectory: directory,
        retryScheduler: UploadRetryScheduler(backoffSeconds: [900], timeBoxSeconds: 1_800),
        failureNotifier: UploadFailureNotifier()),
      replayRepository: CompletedVideoDemoRepository())
  }

  private static func seed(directory: URL) -> [VideoAttachment] {
    let plan = StudentDemoSeed.makePlanView()
    let logs = StudentDemoSeed.makeHistoricalLogs(studentID: StudentDemoSeed.studentID)
    return plan.days.prefix(3).enumerated().flatMap { dayIndex, day in
      day.exercises.prefix(dayIndex == 2 ? 2 : 1).compactMap { exercise -> VideoAttachment? in
        guard !has("notification") || dayIndex == 2,
          let log = logs.first(where: { $0.planExerciseID == exercise.id })
        else { return nil }
        let name = "\(log.id.uuidString).mp4"
        let file = directory.appending(path: name)
        if !missing,
          let clip = Bundle.main.url(forResource: "coach-demo-video", withExtension: "mp4")
        {
          try? FileManager.default.copyItem(at: clip, to: file)
        }
        let size = (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        return VideoAttachment(
          id: log.id, setLogID: log.id, studentID: log.studentID, status: .pending,
          contentType: "video/mp4", durationSeconds: 10, sizeBytes: Int64(size),
          localFileName: name, recordedAt: log.loggedAt, trainingDate: day.scheduledDate,
          uploadRetryCount: 1,
          firstUploadFailureAt: Date().addingTimeInterval(has("notification") ? -1801 : 0))
      }
    }
  }

  private static func has(_ name: String) -> Bool {
    ProcessInfo.processInfo.arguments.contains("--spec101-\(name)")
  }
}

private struct VideoDeliveryDemoSession: SessionStateReader {
  func accessToken() async throws -> String { "demo-local-transport" }
  func currentUser() async throws -> User { throw SessionStateReaderError.missingCurrentUser }
}

/// Demo builds omit the production push delegate. Mirror only its local route.
private final class VideoDeliveryDemoNotifications: NSObject, UNUserNotificationCenterDelegate,
  @unchecked Sendable
{
  static let shared = VideoDeliveryDemoNotifications()

  func userNotificationCenter(
    _ center: UNUserNotificationCenter, willPresent notification: UNNotification
  ) async -> UNNotificationPresentationOptions {
    [.banner, .sound, .list]
  }

  func userNotificationCenter(
    _ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse
  ) async {
    if let destination = UploadFailureDestination(
      notificationUserInfo: response.notification.request.content.userInfo)
    {
      UploadFailureNavigation.shared.openFailedAttachment(destination)
    }
  }
}
