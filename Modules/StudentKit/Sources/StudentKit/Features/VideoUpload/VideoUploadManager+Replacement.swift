import CoreModels
import Foundation

extension VideoUploadManager {
  func needsReplacement(attachmentID: UUID) async -> Bool {
    guard let record = try? await repository.fetch(id: attachmentID), record.status != .uploaded
    else {
      return false
    }
    return !FileManager.default.fileExists(atPath: fileURL(for: record).path)
      && retainedSourceURL(recordID: attachmentID) == nil
  }

  /// Restores only missing media, preserving the durable identity and set binding.
  /// Copy first: picker/import failures must never remove the recovery record.
  func replaceMissingSource(attachmentID: UUID, sourceURL: URL) async throws {
    guard !removingRecordIDs.contains(attachmentID), activeUploads[attachmentID] == nil,
      let record = try await repository.fetch(id: attachmentID), record.status != .uploaded,
      await needsReplacement(attachmentID: attachmentID)
    else { return }
    let duration = try await diagnosedDuration(of: sourceURL)
    guard duration <= configuration.maxDurationSeconds + Self.durationGraceSeconds else {
      VideoProcessingDiagnostics().report(.duration, code: .tooLong)
      throw VideoUploadError.durationExceedsLimit(
        seconds: duration, maxSeconds: configuration.maxDurationSeconds)
    }
    guard !removingRecordIDs.contains(attachmentID),
      try await repository.fetch(id: attachmentID) != nil
    else { return }
    try FileManager.default.createDirectory(at: filesDirectory, withIntermediateDirectories: true)
    let destination = sourceFileURL(recordID: attachmentID, pathExtension: sourceURL.pathExtension)
    try FileManager.default.copyItem(at: sourceURL, to: destination)
    try? FileManager.default.removeItem(at: sourceURL)
    await retry(attachmentID: attachmentID)
  }
}
