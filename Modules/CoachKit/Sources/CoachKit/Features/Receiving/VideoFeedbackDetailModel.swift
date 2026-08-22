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
  private(set) var setInfoState: VideoSetInfoState = .loading
  private(set) var markers: [VideoMarker]?
  /// The endpoint answered but with an error other than 404 — the marker
  /// surface stays visible with a failure row instead of vanishing.
  private(set) var markersFailed = false
  private(set) var markerActionFailure: VideoMarkerActionFailure?

  enum VideoMarkerActionFailure: Equatable {
    case save
    case delete
  }

  var isResolvingPlayback: Bool {
    resolvingPlaybackItemID == currentItem.id
  }

  var setInfo: VideoSetInfo? {
    guard case .loaded(let info) = setInfoState else { return nil }
    return info
  }

  @ObservationIgnored private var playbackRequestID: UUID?
  @ObservationIgnored private var setInfoRequestID: UUID?
  @ObservationIgnored private var markersRequestID: UUID?
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
    trainingLogs: any StudentTrainingLogRepository,
    markerRepository: any VideoMarkerRepository = InMemoryVideoMarkerRepository()
  ) async {
    invalidateRequests()
    resetPresentation()
    async let playback: Void = loadPlayback(using: videoQueue)
    async let metrics: Void = loadSetInfo(using: trainingLogs)
    async let markerLoad: Void = loadMarkers(using: markerRepository)
    _ = await (playback, metrics, markerLoad)
  }

  func createMarker(
    timeMilliseconds: Int,
    level: VideoMarkerLevel,
    note: String,
    using repository: any VideoMarkerRepository
  ) async {
    let itemID = currentItem.id
    markerActionFailure = nil
    do {
      let created = try await repository.createMarker(
        videoID: itemID,
        timeMilliseconds: timeMilliseconds,
        level: level,
        note: note
      )
      guard currentItem.id == itemID, markers != nil else { return }
      markers?.append(created)
      markers?.sort(by: Self.markerOrder)
    } catch {
      guard currentItem.id == itemID else { return }
      markerActionFailure = .save
    }
  }

  func deleteMarker(
    _ marker: VideoMarker,
    using repository: any VideoMarkerRepository
  ) async {
    let itemID = currentItem.id
    markerActionFailure = nil
    do {
      try await repository.deleteMarker(videoID: itemID, markerID: marker.id)
      guard currentItem.id == itemID else { return }
      markers?.removeAll { $0.id == marker.id }
    } catch {
      guard currentItem.id == itemID else { return }
      markerActionFailure = .delete
    }
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

  func reloadMarkers(using repository: any VideoMarkerRepository) async {
    await loadMarkers(using: repository)
  }

  private func loadSetInfo(using trainingLogs: any StudentTrainingLogRepository) async {
    let item = currentItem
    guard let setLogID = item.setLogID else {
      setInfoState = .unlinked
      return
    }

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
      guard accepts(requestID: requestID, itemID: item.id, kind: .setInfo) else {
        return
      }
      setInfoState = .failed
      return
    }

    guard accepts(requestID: requestID, itemID: item.id, kind: .setInfo) else {
      return
    }
    if let info = VideoSetInfo.resolve(setLogID: setLogID, from: logs) {
      setInfoState = .loaded(info)
    } else {
      setInfoState = .failed
    }
  }

  private func loadMarkers(using repository: any VideoMarkerRepository) async {
    let item = currentItem
    let requestID = UUID()
    markersRequestID = requestID
    do {
      let loaded = try await repository.markers(videoID: item.id)
      guard accepts(requestID: requestID, itemID: item.id, kind: .markers) else {
        return
      }
      markers = loaded.sorted(by: Self.markerOrder)
      markersFailed = false
    } catch {
      guard accepts(requestID: requestID, itemID: item.id, kind: .markers) else {
        return
      }
      // A 404 means the endpoint may not be deployed yet: the entire marker
      // surface is optional and disappears without affecting video feedback.
      // Fail safe: only that recognized signal hides the surface — any other
      // error keeps a visible failure row so markers never vanish silently.
      markers = nil
      markersFailed = (error as? VideoMarkerRepositoryError) != .unavailable
    }
  }

  private func invalidateRequests() {
    playbackRequestID = nil
    setInfoRequestID = nil
    markersRequestID = nil
    resolvingPlaybackItemID = nil
  }

  private func resetPresentation() {
    playbackURL = nil
    playbackError = false
    setInfoState = .loading
    markers = nil
    markersFailed = false
    markerActionFailure = nil
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
    case .markers:
      return markersRequestID == requestID
    }
  }

  private static func markerOrder(_ lhs: VideoMarker, _ rhs: VideoMarker) -> Bool {
    if lhs.timeMilliseconds != rhs.timeMilliseconds {
      return lhs.timeMilliseconds < rhs.timeMilliseconds
    }
    return lhs.createdAt < rhs.createdAt
  }

  private enum RequestKind {
    case playback
    case setInfo
    case markers
  }
}

enum VideoSetInfoState: Equatable, Sendable {
  case loading
  case unlinked
  case loaded(VideoSetInfo)
  case failed
}
