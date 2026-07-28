import CoreModels
import Foundation

enum SetRefVideoResolution: Sendable {
  case waiting
  case resolved(UUID?)
}

struct SetRefSendOperation: Sendable {
  let intent: SetRefSendIntent
  var videoResolution: SetRefVideoResolution
}

extension ChatSendCoordinator {
  public func makeSetRefIntent(
    in conversationID: UUID,
    source: SetRefSourceSnapshot,
    note: String?,
    video: SetRefVideoSelection? = nil
  ) throws -> SetRefSendIntent {
    let setRef = try SetRefV1.normalizingSource(source)
    return SetRefSendIntent(
      conversationID: conversationID,
      clientID: Self.makeClientID(),
      setRef: setRef,
      body: SetRefCanonicalFormatter.body(for: setRef, note: note),
      video: video
    )
  }

  /// Enqueues an already-frozen intent. Repeated calls with the same intent
  /// reuse its client ID and cannot create a second in-flight operation.
  @discardableResult
  public func sendSetRef(_ intent: SetRefSendIntent) -> String {
    let videoResolution: SetRefVideoResolution
    switch intent.video {
    case .none:
      videoResolution = .resolved(nil)
    case .ready(let videoID):
      videoResolution = .resolved(videoID)
    case .uploading:
      videoResolution = .waiting
    }
    return enqueue(
      .text(intent.body),
      in: intent.conversationID,
      clientID: intent.clientID,
      setRefOperation: SetRefSendOperation(
        intent: intent,
        videoResolution: videoResolution
      )
    )
  }

  func resolveVideoID(
    for operation: SetRefSendOperation,
    key: ChatSendOperationKey
  ) async throws -> UUID? {
    switch operation.videoResolution {
    case .resolved(let videoID):
      return videoID
    case .waiting:
      break
    }

    guard
      case .uploading(let localAttachmentID, let events) = operation.intent.video
    else {
      return nil
    }

    for await event in events {
      try Task.checkCancellation()
      switch event {
      case .ready(let eventAttachmentID, let videoID)
      where eventAttachmentID == localAttachmentID:
        if var current = setRefOperations[key] {
          current.videoResolution = .resolved(videoID)
          setRefOperations[key] = current
        }
        return videoID
      case .failed(let eventAttachmentID) where eventAttachmentID == localAttachmentID:
        throw SetRefSendError.videoUploadFailed
      case .removed(let eventAttachmentID) where eventAttachmentID == localAttachmentID:
        throw SetRefSendError.videoUploadRemoved
      default:
        continue
      }
    }

    try Task.checkCancellation()
    throw SetRefSendError.videoUploadEnded
  }
}
