import CoreModels
import Foundation
import RepositoryContracts

@testable import StudentKit

enum MockServiceError: Error, Equatable {
  case partFailed
  case initiateFailed
  case exportFailed
}

struct TimeoutError: Error {}

enum LocalDeletionTestError: Error {
  case forcedFailure
}

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

actor RecoveringVideoExporter: VideoExporting {
  private var shouldFail = true
  private(set) var exportAttempts = 0

  func allowExports() {
    shouldFail = false
  }

  func durationSeconds(of sourceURL: URL) async throws -> Double {
    30
  }

  func export(from sourceURL: URL, to destinationURL: URL) async throws {
    exportAttempts += 1
    guard !shouldFail else {
      throw VideoUploadError.exportFailed("forced test failure")
    }
    try Data(repeating: 0xAB, count: 2_560).write(to: destinationURL)
  }
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
