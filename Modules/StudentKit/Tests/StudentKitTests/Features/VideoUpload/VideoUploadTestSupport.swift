import CoreModels
import Foundation
import Networking
import RepositoryContracts

@testable import StudentKit

enum MockServiceError: Error, Equatable {
  case partFailed
  case initiateFailed
  case deleteFailed
  case exportFailed
}

struct TimeoutError: Error {}

/// Deterministic exporter: ignores the source and writes `exportedBytes` of
/// filler to the destination.
struct MockVideoExporter: VideoExporting {
  var duration: Double = 30
  var exportedBytes: Int = 2_560

  func durationSeconds(of sourceURL: URL) async throws -> Double {
    duration
  }

  func export(from sourceURL: URL, to destinationURL: URL) async throws {
    try Data(repeating: 0xAB, count: exportedBytes).write(to: destinationURL)
  }
}

struct FailingVideoExporter: VideoExporting {
  func durationSeconds(of sourceURL: URL) async throws -> Double {
    30
  }

  func export(from sourceURL: URL, to destinationURL: URL) async throws {
    throw MockServiceError.exportFailed
  }
}

/// Records the wire-call order of the upload pipeline and lets tests inject
/// per-part failures, complete errors, and a hang (for cancellation tests).
actor MockVideoUploadService: VideoUploadService {
  let remoteAttachmentID = UUID()

  private(set) var calls: [String] = []
  private(set) var partAttempts: [Int: Int] = [:]
  private(set) var abortCount = 0
  private(set) var deleteCount = 0

  private var partFailuresRemaining: [Int: Int] = [:]
  private var completeError: Error?
  private var deleteError: Error?
  private var hangOnParts = false

  func setPartFailures(_ failures: [Int: Int]) {
    partFailuresRemaining = failures
  }

  func setCompleteError(_ error: Error?) {
    completeError = error
  }

  func setDeleteError(_ error: Error?) {
    deleteError = error
  }

  func setHangOnParts(_ hang: Bool) {
    hangOnParts = hang
  }

  func initiate(_ request: InitiateUploadRequestDTO) async throws -> InitiateUploadResponseDTO {
    calls.append("initiate:\(request.partCount):\(request.filename ?? "-")")
    let partURLs = (1...request.partCount).map { partNumber in
      UploadPartURLDTO(partNumber: partNumber, url: "https://oss.test/parts/\(partNumber)")
    }
    return InitiateUploadResponseDTO(
      attachmentID: remoteAttachmentID,
      uploadID: "upload-1",
      partURLs: partURLs
    )
  }

  func uploadPart(to url: URL, data: Data) async throws -> String {
    let partNumber = Int(url.lastPathComponent) ?? 0
    calls.append("part:\(partNumber)")
    partAttempts[partNumber, default: 0] += 1
    if hangOnParts {
      try await Task.sleep(for: .seconds(60))
    }
    if let remaining = partFailuresRemaining[partNumber], remaining > 0 {
      partFailuresRemaining[partNumber] = remaining - 1
      throw MockServiceError.partFailed
    }
    return "etag-\(partNumber)"
  }

  func complete(attachmentID: UUID, parts: [UploadPartETagDTO]) async throws -> AttachmentDTO {
    let partList = parts.map { String($0.partNumber) }.joined(separator: ",")
    calls.append("complete:\(partList)")
    if let completeError {
      throw completeError
    }
    return AttachmentDTO(
      id: attachmentID,
      ownerID: UUID(),
      kind: .setVideo,
      ossKey: "attachments/test/\(attachmentID.uuidString).mp4",
      contentType: "video/mp4",
      sizeBytes: 1,
      filename: nil,
      status: .ready,
      createdAt: Date(),
      updatedAt: Date()
    )
  }

  func abort(attachmentID: UUID) async throws {
    calls.append("abort")
    abortCount += 1
  }

  func delete(attachmentID: UUID) async throws {
    calls.append("delete")
    deleteCount += 1
    if let deleteError {
      throw deleteError
    }
  }
}

/// Test fixture: a manager wired against mocks, with a throwaway files
/// directory under tmp.
struct VideoUploadHarness {
  let service: MockVideoUploadService
  let repository: InMemoryVideoAttachmentRepository
  let manager: VideoUploadManager
  let filesDirectory: URL
  let sourceURL = URL(fileURLWithPath: "/tmp/ignored-source.mov")

  init(
    exporter: any VideoExporting = MockVideoExporter(),
    configuration: VideoUploadConfiguration = VideoUploadHarness.testConfiguration()
  ) {
    let service = MockVideoUploadService()
    let repository = InMemoryVideoAttachmentRepository()
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("video-upload-tests-\(UUID().uuidString)", isDirectory: true)
    self.service = service
    self.repository = repository
    self.filesDirectory = directory
    self.manager = VideoUploadManager(
      service: service,
      exporter: exporter,
      repository: repository,
      configuration: configuration,
      filesDirectory: directory
    )
  }

  /// Small parts + zero retry delay + serial parts so call order is exact.
  static func testConfiguration(
    maxConcurrentParts: Int = 1,
    partRetryCount: Int = 2
  ) -> VideoUploadConfiguration {
    VideoUploadConfiguration(
      partSizeBytes: 1_024,
      maxDurationSeconds: 120,
      partRetryCount: partRetryCount,
      maxConcurrentParts: maxConcurrentParts,
      partRetryDelay: .zero
    )
  }
}

func makeTemporaryVideoSource() throws -> URL {
  let sourceURL = FileManager.default.temporaryDirectory
    .appending(path: "video-upload-source-\(UUID().uuidString).mov")
  try Data([0x01]).write(to: sourceURL)
  return sourceURL
}

func waitForStatus(
  _ repository: any VideoAttachmentRepository,
  id: UUID,
  oneOf statuses: Set<VideoAttachment.Status>,
  timeoutMilliseconds: Int = 5_000
) async throws -> VideoAttachment {
  for _ in 0..<(timeoutMilliseconds / 10) {
    if let record = try await repository.fetch(id: id), statuses.contains(record.status) {
      return record
    }
    try await Task.sleep(for: .milliseconds(10))
  }
  throw TimeoutError()
}

func waitUntil(
  timeoutMilliseconds: Int = 5_000,
  _ condition: () async throws -> Bool
) async throws {
  for _ in 0..<(timeoutMilliseconds / 10) {
    if try await condition() {
      return
    }
    try await Task.sleep(for: .milliseconds(10))
  }
  throw TimeoutError()
}

/// MainActor twin of `waitUntil` so view-model state can be polled without
/// shipping the non-Sendable view model across isolation domains.
@MainActor
func waitUntilOnMain(
  timeoutMilliseconds: Int = 5_000,
  _ condition: @MainActor () async throws -> Bool
) async throws {
  for _ in 0..<(timeoutMilliseconds / 10) {
    if try await condition() {
      return
    }
    try await Task.sleep(for: .milliseconds(10))
  }
  throw TimeoutError()
}
