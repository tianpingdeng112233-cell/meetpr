import CoreModels
import Foundation

public enum SetRefVideoUploadEvent: Equatable, Sendable {
  case ready(localAttachmentID: UUID, videoID: UUID)
  case failed(localAttachmentID: UUID)
  case removed(localAttachmentID: UUID)
}

public enum SetRefVideoSelection: Sendable {
  case ready(videoID: UUID)
  case uploading(
    localAttachmentID: UUID,
    events: AsyncStream<SetRefVideoUploadEvent>
  )
}

public enum SetRefSendError: Error, Equatable, Sendable {
  case videoUploadFailed
  case videoUploadRemoved
  case videoUploadEnded
}

/// Immutable session-owned send intent. The set snapshot, canonical body,
/// selected upload, and idempotency key are all frozen when this value is made.
public struct SetRefSendIntent: Sendable {
  public let conversationID: UUID
  public let clientID: String
  public let setRef: SetRefV1
  public let body: String
  public let video: SetRefVideoSelection?
}
