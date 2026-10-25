import ChatUI
import CoreModels
import Foundation
import Observation

@MainActor @Observable
final class CompletedVideoReplayModel {
  struct Request: Identifiable {
    let id = UUID()
    let video: CompletedSetVideo
    let badge: VideoBadgeInfo
  }

  private(set) var videos: [StudentVideo] = []
  private var attachments: [UUID: VideoAttachment] = [:]
  var selected: Request?
  let feedback: FeedbackInboxViewModel?
  private let services: VideoUploadServices
  @ObservationIgnored nonisolated(unsafe) private var observer: Task<Void, Never>?

  init(services: VideoUploadServices, feedback: FeedbackInboxViewModel?) {
    self.services = services
    self.feedback = feedback
  }

  deinit { observer?.cancel() }

  var local: [VideoAttachment] { Array(attachments.values) }

  func load(studentID: UUID) async {
    if observer == nil {
      let events = await services.manager.events()
      if let stored = try? await services.manager.repository.fetchAll(studentID: studentID) {
        attachments = Dictionary(uniqueKeysWithValues: stored.map { ($0.id, $0) })
      }
      observer = Task { [weak self] in
        for await event in events {
          guard !Task.isCancelled else { return }
          self?.apply(event, studentID: studentID)
        }
      }
    }
    if let repository = services.replayRepository,
      let remote = try? await repository.fetchVideos(studentID: studentID)
    {
      videos = remote
    }
    await feedback?.load(studentID: studentID)
  }

  func uploadState(setLogID: UUID?) -> VideoAttachment? {
    guard let setLogID else { return nil }
    let latest = local.filter { $0.setLogID == setLogID }.max { $0.recordedAt < $1.recordedAt }
    guard let latest, latest.status != .uploaded,
      CompletedSetVideo.resolve(setLogID: setLogID, videos: videos, local: local) == nil
    else { return nil }
    return latest
  }

  func open(_ video: CompletedSetVideo, badge: VideoBadgeInfo) {
    selected = Request(video: video, badge: badge)
  }

  func review(for video: CompletedSetVideo) -> CoachFeedback? {
    let remoteID: UUID?
    switch video {
    case .local(let id): remoteID = attachments[id]?.remoteAttachmentID
    case .remote(let id): remoteID = id
    }
    return CompletedSetVideo.latestFeedback(videoID: remoteID, items: feedback?.items ?? [])
  }

  func source(for video: CompletedSetVideo) async throws -> VideoAttachmentPlaybackSource {
    switch video {
    case .local(let id):
      guard let source = try await services.manager.playbackSource(attachmentID: id) else {
        throw VideoAttachmentPlaybackError.unavailable
      }
      return source
    case .remote(let id):
      let url = try await freshURL(for: .remote(id))
      return url.isFileURL ? .local(url) : .remote(url)
    }
  }

  func freshURL(for video: CompletedSetVideo) async throws -> URL {
    switch video {
    case .local(let id):
      return try await services.manager.freshRemotePlaybackURL(attachmentID: id)
    case .remote(let id):
      guard let repository = services.replayRepository else {
        throw VideoAttachmentPlaybackError.unavailable
      }
      return try await repository.playbackURL(videoID: id)
    }
  }

  private func apply(_ event: VideoUploadEvent, studentID: UUID) {
    switch event {
    case .updated(let attachment, _) where attachment.studentID == studentID:
      attachments[attachment.id] = attachment
    case .removed(_, let attachmentID):
      if let remoteID = attachments[attachmentID]?.remoteAttachmentID {
        videos.removeAll { $0.id == remoteID }
      }
      attachments[attachmentID] = nil
    default: break
    }
  }
}
