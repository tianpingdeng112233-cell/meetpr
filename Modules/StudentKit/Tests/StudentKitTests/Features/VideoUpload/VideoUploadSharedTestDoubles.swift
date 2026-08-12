import Foundation

@testable import StudentKit

final class RecoveryLockedCounter: @unchecked Sendable {
  private let lock = NSLock()
  private var storage = 0

  var value: Int { lock.withLock { storage } }

  func increment() {
    lock.withLock { storage += 1 }
  }
}

actor RecordingUploadFailureNotifier: UploadFailureNotifying {
  private(set) var authorizationRequestCount = 0
  private(set) var notifiedCounts: [Int] = []
  private(set) var destinations: [UploadFailureDestination] = []

  func requestProvisionalAuthorization() async {
    authorizationRequestCount += 1
  }

  func notifyTerminalFailures(count: Int, destination: UploadFailureDestination) async {
    notifiedCounts.append(count)
    destinations.append(destination)
  }
}

func makeTemporaryVideoSource() throws -> URL {
  let sourceURL = FileManager.default.temporaryDirectory
    .appending(path: "video-upload-source-\(UUID().uuidString).mov")
  try Data([0x01]).write(to: sourceURL)
  return sourceURL
}

/// Test fixture: a manager wired against mocks, with a throwaway files
/// directory under tmp.
struct VideoUploadHarness {
  let service: MockVideoUploadService
  let repository: InMemoryVideoAttachmentRepository
  let manager: VideoUploadManager
  let filesDirectory: URL
  let sourceURL: URL

  init(
    exporter: any VideoExporting = MockVideoExporter(),
    configuration: VideoUploadConfiguration = VideoUploadHarness.testConfiguration(),
    failureNotifier: (any UploadFailureNotifying)? = nil
  ) {
    let service = MockVideoUploadService()
    let repository = InMemoryVideoAttachmentRepository()
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("video-upload-tests-\(UUID().uuidString)", isDirectory: true)
    self.service = service
    self.repository = repository
    self.filesDirectory = directory
    self.sourceURL = directory.appending(path: "incoming.mov")
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try? Data([0x01]).write(to: self.sourceURL)
    self.manager = VideoUploadManager(
      service: service,
      exporter: exporter,
      repository: repository,
      configuration: configuration,
      filesDirectory: directory,
      retryScheduler: UploadRetryScheduler(
        backoffSeconds: [0, 0, 0, 0, 0],
        timeBoxSeconds: 30 * 60
      ),
      failureNotifier: failureNotifier
    )
  }

  /// Small parts + zero retry delay + serial parts so call order is exact.
  static func testConfiguration(maxConcurrentParts: Int = 1) -> VideoUploadConfiguration {
    VideoUploadConfiguration(
      partSizeBytes: 1_024,
      maxDurationSeconds: 120,
      maxConcurrentParts: maxConcurrentParts
    )
  }
}
