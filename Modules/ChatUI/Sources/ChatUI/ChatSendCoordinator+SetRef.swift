import CoreModels
import Foundation

enum SetRefMessageLengthPolicy {
  static let maximumBodyUTF16Count = 4_000

  static func isAllowed(_ body: String) -> Bool {
    body.utf16.count <= maximumBodyUTF16Count
  }
}

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
    let body = SetRefCanonicalFormatter.body(for: setRef, note: note)
    guard SetRefMessageLengthPolicy.isAllowed(body) else {
      throw SetRefSendError.messageTooLong
    }
    return SetRefSendIntent(
      conversationID: conversationID,
      clientID: Self.makeClientID(),
      setRef: setRef,
      body: body,
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

  public func stageSetRef(_ intent: SetRefSendIntent) {
    stagedSetRefsByConversationID[intent.conversationID] = intent
  }

  public func stagedSetRef(in conversationID: UUID) -> SetRefSendIntent? {
    stagedSetRefsByConversationID[conversationID]
  }

  public func discardStagedSetRef(in conversationID: UUID) {
    stagedSetRefsByConversationID[conversationID] = nil
  }

  /// Sends a staged snapshot with the note currently in the composer.
  ///
  /// The snapshot, upload selection, and client ID remain the values frozen at
  /// confirmation time. Only the canonical body is regenerated to append the
  /// student's optional note.
  @discardableResult
  public func sendStagedSetRef(
    in conversationID: UUID,
    note: String?
  ) throws -> String {
    guard let staged = stagedSetRefsByConversationID[conversationID] else {
      throw SetRefSendError.missingStagedIntent
    }
    let body = SetRefCanonicalFormatter.body(for: staged.setRef, note: note)
    guard SetRefMessageLengthPolicy.isAllowed(body) else {
      throw SetRefSendError.messageTooLong
    }
    stagedSetRefsByConversationID[conversationID] = nil
    let intent = SetRefSendIntent(
      conversationID: staged.conversationID,
      clientID: staged.clientID,
      setRef: staged.setRef,
      body: body,
      video: staged.video
    )
    return sendSetRef(intent)
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
