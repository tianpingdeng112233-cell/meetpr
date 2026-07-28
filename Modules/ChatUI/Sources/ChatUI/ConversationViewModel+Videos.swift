import CoreModels
import Foundation
import RepositoryContracts

enum ChatVideoPlaybackError: Error, Equatable, Sendable {
  case unavailable
}

@MainActor
extension ConversationViewModel {
  public func refreshVideosIfNeeded() async {
    let videoIDs = messages.compactMap { message -> UUID? in
      guard message.setRef != nil, message.videoURL != nil else {
        return nil
      }
      return videoNeedsRenewal(message) ? message.id : nil
    }
    for messageID in videoIDs {
      try? await renewVideo(messageID: messageID, force: false)
    }
  }

  func videoPlaybackURL(
    messageID: UUID,
    forceRenewal: Bool = false
  ) async throws -> URL {
    guard
      let target = message(withID: messageID),
      target.setRef != nil,
      target.videoURL != nil
    else {
      throw ChatVideoPlaybackError.unavailable
    }

    if forceRenewal || videoNeedsRenewal(target) {
      try await renewVideo(messageID: messageID, force: forceRenewal)
    }

    guard
      let refreshed = message(withID: messageID),
      refreshed.setRef != nil,
      let url = refreshed.videoURL,
      !url.absoluteString.isEmpty
    else {
      throw ChatVideoPlaybackError.unavailable
    }
    return url
  }

  private func videoNeedsRenewal(_ message: ChatMessage) -> Bool {
    guard
      message.setRef != nil,
      message.videoURL != nil,
      let expiresIn = message.videoExpiresIn,
      let obtainedAt = videoURLObtainedAt[message.id]
    else {
      return false
    }
    return now() >= obtainedAt.addingTimeInterval(TimeInterval(expiresIn))
  }

  private func renewVideo(messageID: UUID, force: Bool) async throws {
    guard
      !videoRenewalsInFlight.contains(messageID),
      let target = message(withID: messageID),
      target.setRef != nil,
      target.videoURL != nil,
      force || videoNeedsRenewal(target)
    else {
      return
    }

    videoRenewalsInFlight.insert(messageID)
    defer { videoRenewalsInFlight.remove(messageID) }
    do {
      let query = try ChatMessageQuery.before(seq: target.seq + 1, limit: 1)
      let page = try await repository.fetchMessages(in: conversationID, query: query)
      guard
        let refreshed = page.messages.first,
        refreshed.id == target.id,
        refreshed.seq == target.seq
      else {
        if target.senderID == currentUserID {
          markVideoUnavailable(for: target)
        } else {
          removeMessageLocally(messageID: target.id, seq: target.seq)
        }
        throw ChatVideoPlaybackError.unavailable
      }
      guard
        let index = messages.firstIndex(where: {
          $0.id == target.id && $0.seq == target.seq
        })
      else {
        throw ChatVideoPlaybackError.unavailable
      }

      messages[index] = refreshed
      if refreshed.videoURL != nil {
        videoURLObtainedAt[refreshed.id] = now()
      } else {
        videoURLObtainedAt.removeValue(forKey: refreshed.id)
      }
    } catch {
      if error as? ChatVideoPlaybackError == .unavailable {
        throw error
      }
      handle(error)
      throw error
    }
  }

  private func removeMessageLocally(messageID: UUID, seq: Int) {
    removedMessageIDs.insert(messageID)
    messages.removeAll { $0.id == messageID && $0.seq == seq }
    videoURLObtainedAt.removeValue(forKey: messageID)
  }

  private func markVideoUnavailable(for message: ChatMessage) {
    guard let index = messages.firstIndex(where: { $0.id == message.id }) else {
      return
    }
    messages[index] = ChatMessage(
      id: message.id,
      conversationID: message.conversationID,
      seq: message.seq,
      senderID: message.senderID,
      kind: message.kind,
      text: message.text,
      attachmentID: message.attachmentID,
      imageURL: message.imageURL,
      imageExpiresIn: message.imageExpiresIn,
      setRef: message.setRef,
      videoURL: nil,
      videoExpiresIn: nil,
      clientID: message.clientID,
      createdAt: message.createdAt
    )
    videoURLObtainedAt.removeValue(forKey: message.id)
  }
}
