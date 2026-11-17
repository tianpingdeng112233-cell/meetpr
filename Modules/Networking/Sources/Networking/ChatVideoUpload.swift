import CoreModels
import Foundation
import RepositoryContracts

/// Reads one bounded part at a time, never materializing a 200 MB video in memory.
struct ChatVideoUpload {
  let apiClient: APIClient
  let uploader: OSSPartUploader

  func upload(
    _ video: ChatVideoFile, clientID: String, accessToken: String,
    progress: @escaping @Sendable (Double) async -> Void
  ) async throws -> UUID {
    try Task.checkCancellation()
    let size = try validatedSize(video)

    let partSize = 5 * 1024 * 1024
    let partCount = (size + partSize - 1) / partSize
    await progress(0)
    let initiated = try await apiClient.initiateUpload(
      InitiateUploadRequestDTO(
        kind: .chatVideo, contentType: video.contentType, sizeBytes: video.byteCount,
        partCount: partCount,
        filename: "chat-\(clientID).\(video.contentType == "video/mp4" ? "mp4" : "mov")"),
      accessToken: accessToken)
    var completed = false
    do {
      let parts = initiated.partURLs.sorted { $0.partNumber < $1.partNumber }
      guard parts.map(\.partNumber) == Array(1...partCount) else {
        throw APIError.invalidResponse
      }
      let handle = try FileHandle(forReadingFrom: video.fileURL)
      defer { try? handle.close() }
      var uploaded = 0
      var etags: [UploadPartETagDTO] = []
      for part in parts {
        try Task.checkCancellation()
        let expectedSize = min(partSize, size - uploaded)
        guard let url = URL(string: part.url),
          let data = try handle.read(upToCount: expectedSize), data.count == expectedSize
        else { throw APIError.invalidResponse }
        let etag = try await uploader.uploadPart(to: url, data: data)
        uploaded += data.count
        etags.append(UploadPartETagDTO(partNumber: part.partNumber, etag: etag))
        await progress(Double(uploaded) / Double(size))
      }
      try Task.checkCancellation()
      let attachment = try await apiClient.completeUpload(
        attachmentID: initiated.attachmentID, parts: etags, accessToken: accessToken)
      completed = true
      guard attachment.id == initiated.attachmentID,
        attachment.kind == .chatVideo, attachment.status == .ready
      else { throw APIError.invalidResponse }
      return attachment.id
    } catch {
      await cleanupChatAttachment(
        initiated.attachmentID, completed: completed, apiClient: apiClient, accessToken: accessToken
      )
      throw error
    }
  }
  private func validatedSize(_ video: ChatVideoFile) throws -> Int {
    let attributes = try video.fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
    guard video.fileURL.isFileURL, attributes.isRegularFile == true,
      let size = attributes.fileSize, Int64(size) == video.byteCount,
      video.byteCount > 0, video.byteCount <= ChatVideoFile.maximumByteCount,
      ["video/mp4", "video/quicktime"].contains(video.contentType)
    else { throw ChatRepositoryError.invalidAttachment }

    return size
  }

}
