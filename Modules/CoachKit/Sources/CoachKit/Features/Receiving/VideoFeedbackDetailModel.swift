import CoreModels
import Foundation
import Observation
import RepositoryContracts

/// Item-scoped loading state for the video-feedback workbench.
///
/// URL and training-log repositories may ignore task cancellation. Request
/// tokens plus the current item identity prevent those stale results from
/// being rendered under a newer clip's header.
@Observable
@MainActor
final class VideoFeedbackDetailModel {
  private(set) var currentItem: PendingVideoItem
  private(set) var playbackURL: URL?
  private(set) var playbackError = false
  private(set) var setInfo: VideoSetInfo?

  var isResolvingPlayback: Bool {
    resolvingPlaybackItemID == currentItem.id
  }

  @ObservationIgnored private var playbackRequestID: UUID?
  @ObservationIgnored private var setInfoRequestID: UUID?
  @ObservationIgnored private var resolvingPlaybackItemID: UUID?

  init(item: PendingVideoItem) {
    currentItem = item
  }

  func select(_ item: PendingVideoItem) {
    invalidateRequests()
    currentItem = item
    resetPresentation()
  }

  func prepare(
    videoQueue: CoachVideoQueueViewModel,
    trainingLogs: any StudentTrainingLogRepository
  ) async {
    invalidateRequests()
    resetPresentation()
    async let playback: Void = loadPlayback(using: videoQueue)
    async let metrics: Void = loadSetInfo(using: trainingLogs)
    _ = await (playback, metrics)
  }

  func loadPlayback(using videoQueue: CoachVideoQueueViewModel) async {
    let item = currentItem
    let requestID = UUID()
    playbackRequestID = requestID
    resolvingPlaybackItemID = item.id
    playbackError = false

    defer {
      if playbackRequestID == requestID {
        playbackRequestID = nil
        resolvingPlaybackItemID = nil
      }
    }

    do {
      let resolvedURL = try await videoQueue.playbackURL(videoID: item.id)
      guard accepts(requestID: requestID, itemID: item.id, kind: .playback) else {
        return
      }
      playbackURL = resolvedURL
    } catch {
      guard accepts(requestID: requestID, itemID: item.id, kind: .playback) else {
        return
      }
      playbackURL = nil
      playbackError = true
    }
  }

  private func loadSetInfo(using trainingLogs: any StudentTrainingLogRepository) async {
    let item = currentItem
    guard let setLogID = item.setLogID else { return }

    let requestID = UUID()
    setInfoRequestID = requestID
    let logs: [StudentSetLog]
    do {
      if let planExerciseID = item.planExerciseID {
        logs = try await trainingLogs.fetchLogsForExercise(
          studentID: item.studentID,
          planExerciseID: planExerciseID
        )
      } else {
        logs = try await trainingLogs.fetchLogs(
          studentID: item.studentID,
          in: CoachFeatureCalendar.dateRange(
            starting: item.dayDate ?? item.uploadedAt,
            days: 1
          )
        )
      }
    } catch {
      return
    }

    guard accepts(requestID: requestID, itemID: item.id, kind: .setInfo) else {
      return
    }
    setInfo = VideoSetInfo.resolve(setLogID: setLogID, from: logs)
  }

  private func invalidateRequests() {
    playbackRequestID = nil
    setInfoRequestID = nil
    resolvingPlaybackItemID = nil
  }

  private func resetPresentation() {
    playbackURL = nil
    playbackError = false
    setInfo = nil
  }

  private func accepts(
    requestID: UUID,
    itemID: UUID,
    kind: RequestKind
  ) -> Bool {
    guard !Task.isCancelled, currentItem.id == itemID else { return false }
    switch kind {
    case .playback:
      return playbackRequestID == requestID
    case .setInfo:
      return setInfoRequestID == requestID
    }
  }

  private enum RequestKind {
    case playback
    case setInfo
  }
}
