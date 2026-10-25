import CoreModels
import Foundation

/// A read-only route; local IDs belong to the upload queue, remote IDs to the server.
enum CompletedSetVideo: Equatable, Sendable {
  case local(UUID)
  case remote(UUID)

  static func resolve(
    setLogID: UUID?, videos: [StudentVideo], local: [VideoAttachment] = []
  ) -> Self? {
    guard let setLogID else { return nil }
    let remote = videos.filter { $0.setLogID == setLogID }.max { $0.createdAt < $1.createdAt }
    let attachment = local.filter { $0.setLogID == setLogID }.max { $0.recordedAt < $1.recordedAt }
    if let attachment,
      remote == nil || attachment.remoteAttachmentID == remote?.id
        || attachment.recordedAt >= (remote?.createdAt ?? .distantPast)
    {
      return attachment.status == .uploaded ? .local(attachment.id) : nil
    }
    return remote.map { .remote($0.id) }
  }
  static func latestFeedback(videoID: UUID?, items: [CoachFeedback]) -> CoachFeedback? {
    guard let videoID else { return nil }
    return items.filter { $0.videoID == videoID }.max { $0.postedAt < $1.postedAt }
  }
}
