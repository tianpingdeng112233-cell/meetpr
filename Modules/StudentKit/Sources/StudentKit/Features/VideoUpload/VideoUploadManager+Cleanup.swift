import CoreModels
import Foundation
import Networking

extension VideoUploadManager {
  func fileURL(for record: VideoAttachment) -> URL {
    filesDirectory.appendingPathComponent(record.localFileName ?? "\(record.id.uuidString).mp4")
  }

  func chunkDirectory(recordID: UUID) -> URL {
    filesDirectory.appending(path: "\(recordID.uuidString).parts", directoryHint: .isDirectory)
  }

  func removeChunkFiles(recordID: UUID) {
    try? FileManager.default.removeItem(at: chunkDirectory(recordID: recordID))
  }

  func resetRemoteSession(on record: inout VideoAttachment) {
    record.remoteAttachmentID = nil
    record.uploadPartCount = 0
    record.uploadPartTargets = []
    record.uploadedParts = []
  }

  /// Persists cleanup intent before the local attachment forgets the remote
  /// identifier. If both queue persistence and the immediate abort fail, the
  /// caller retains the identifier and can try again later.
  @discardableResult
  func abandonRemoteSession(record: inout VideoAttachment) async -> Bool {
    guard let remoteID = record.remoteAttachmentID else {
      resetRemoteSession(on: &record)
      return true
    }
    do {
      try await cleanupStore.enqueue(remoteID)
    } catch {
      do {
        try await service.abort(attachmentID: remoteID)
        resetRemoteSession(on: &record)
        return true
      } catch {
        return false
      }
    }
    do {
      try await service.abort(attachmentID: remoteID)
      try? await cleanupStore.remove(remoteID)
    } catch {}
    resetRemoteSession(on: &record)
    return true
  }

  func flushPendingRemoteCleanups() async {
    let identifiers = (try? await cleanupStore.pendingAttachmentIDs()) ?? []
    for identifier in identifiers {
      do {
        try await service.abort(attachmentID: identifier)
        try await cleanupStore.remove(identifier)
      } catch let error as APIError where Self.isRemoteCleanupTerminal(error) {
        try? await cleanupStore.remove(identifier)
      } catch {}
    }
  }

  static func isRemoteCleanupTerminal(_ error: APIError) -> Bool {
    if case .httpStatus(let statusCode, _) = error {
      return statusCode == 404 || statusCode == 409
    }
    return false
  }
}
