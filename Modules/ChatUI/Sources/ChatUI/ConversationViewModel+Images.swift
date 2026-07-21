import CoreModels
import Foundation
import RepositoryContracts

@MainActor
extension ConversationViewModel {
  public func refreshImagesIfNeeded() async {
    let imageIDs = messages.compactMap { message -> UUID? in
      guard message.kind == .image, message.imageURL != nil else {
        return nil
      }
      return imageNeedsRenewal(message) ? message.id : nil
    }
    for messageID in imageIDs {
      await renewImage(messageID: messageID, force: false)
    }
  }

  public func refreshImageIfNeeded(messageID: UUID) async {
    guard let message = message(withID: messageID), imageNeedsRenewal(message) else {
      return
    }
    await renewImage(messageID: messageID, force: false)
  }

  public func imageLoadingFailed(messageID: UUID) async {
    guard
      let message = message(withID: messageID),
      message.imageURL != nil,
      !loadFailureRenewalAttempted.contains(messageID)
    else {
      return
    }
    loadFailureRenewalAttempted.insert(messageID)
    await renewImage(messageID: messageID, force: true)
  }

  public func imageLoaded(messageID: UUID) {
    loadFailureRenewalAttempted.remove(messageID)
  }

  private func imageNeedsRenewal(_ message: ChatMessage) -> Bool {
    guard
      message.kind == .image,
      message.imageURL != nil,
      let expiresIn = message.imageExpiresIn,
      let obtainedAt = imageURLObtainedAt[message.id]
    else {
      return false
    }
    return now() >= obtainedAt.addingTimeInterval(TimeInterval(expiresIn))
  }

  private func renewImage(messageID: UUID, force: Bool) async {
    guard
      !imageRenewalsInFlight.contains(messageID),
      let target = message(withID: messageID),
      target.kind == .image,
      target.imageURL != nil,
      force || imageNeedsRenewal(target)
    else {
      return
    }
    let attemptTime = now()
    if let lastAttempt = lastImageRenewalAttemptAt[messageID],
      attemptTime.timeIntervalSince(lastAttempt) < 0.5
    {
      return
    }

    imageRenewalsInFlight.insert(messageID)
    lastImageRenewalAttemptAt[messageID] = attemptTime
    defer { imageRenewalsInFlight.remove(messageID) }
    do {
      let query = try ChatMessageQuery.before(seq: target.seq + 1, limit: 1)
      let page = try await repository.fetchMessages(in: conversationID, query: query)
      guard
        let refreshed = page.messages.first,
        refreshed.id == target.id,
        refreshed.seq == target.seq,
        let index = messages.firstIndex(where: {
          $0.id == target.id && $0.seq == target.seq
        })
      else {
        return
      }
      messages[index] = refreshed
      imageURLObtainedAt[refreshed.id] = now()
    } catch {
      handle(error)
    }
  }
}
