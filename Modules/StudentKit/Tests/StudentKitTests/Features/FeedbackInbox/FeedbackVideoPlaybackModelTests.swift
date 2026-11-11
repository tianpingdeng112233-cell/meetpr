import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import StudentKit

@MainActor
struct FeedbackVideoPlaybackModelTests {
  @Test func playbackKeepsCoachMarkersAndCanRenewItsURL() async throws {
    let videoID = UUID()
    let url = try #require(URL(string: "https://example.com/feedback.mp4"))
    let marker = VideoMarker(
      id: UUID(), videoID: videoID, coachID: UUID(), timeMilliseconds: 2000,
      level: .warn, note: "保持核心收紧", createdAt: Date())
    let model = FeedbackVideoPlaybackModel(
      feedback: FeedbackInboxViewModel(
        repository: InMemoryStudentFeedbackRepository(playbackURLs: [videoID: url]),
        markerRepository: InMemoryVideoMarkerRepository(seed: [marker])))
    let item = CoachFeedback(
      id: UUID(), coachID: UUID(), studentID: UUID(), videoID: videoID,
      video: CoachFeedbackVideo(id: videoID), text: "反馈", postedAt: Date())

    await model.open(item)
    #expect(model.selection?.id == videoID)
    #expect(model.selection?.markers == nil)
    await model.refreshMarkers(videoID: videoID)
    #expect(model.selection?.markers == [marker])
    #expect(model.selection?.markersFailed == false)
    #expect(try await model.freshURL(videoID: videoID) == url)
  }

  @Test(arguments: [VideoMarkerRepositoryError.failed, .unavailable])
  func markerFailureDoesNotBlockPlaybackAndCanBeRetried(error: VideoMarkerRepositoryError)
    async throws
  {
    let videoID = UUID()
    let marker = VideoMarker(
      id: UUID(), videoID: videoID, coachID: UUID(), timeMilliseconds: 2000,
      level: .warn, note: "保持核心收紧", createdAt: Date())
    let markers = PlaybackMarkersRepository(error: error, marker: marker)
    let model = FeedbackVideoPlaybackModel(
      feedback: FeedbackInboxViewModel(
        repository: InMemoryStudentFeedbackRepository(
          playbackURLs: [videoID: URL(fileURLWithPath: "/clip.mp4")]),
        markerRepository: markers))
    let item = CoachFeedback(
      id: UUID(), coachID: UUID(), studentID: UUID(), videoID: videoID,
      video: CoachFeedbackVideo(id: videoID), text: "反馈", postedAt: Date())
    await model.open(item)
    #expect(model.selection?.id == videoID)

    await model.refreshMarkers(videoID: videoID)
    #expect(model.selection?.id == videoID)
    #expect(model.selection?.markersFailed == (error == .failed))
    await markers.recover()
    await model.refreshMarkers(videoID: videoID)
    #expect(model.selection?.markers == [marker])
    #expect(model.selection?.markersFailed == false)
  }

  @Test func openingFeedbackSelectsItsVideoAndTrainingBadge() async throws {
    let videoID = UUID()
    let url = try #require(URL(string: "https://example.com/feedback.mp4"))
    let model = FeedbackVideoPlaybackModel(
      feedback: FeedbackInboxViewModel(
        repository: InMemoryStudentFeedbackRepository(playbackURLs: [videoID: url])))
    let item = CoachFeedback(
      id: UUID(), coachID: UUID(), studentID: UUID(), videoID: videoID,
      video: CoachFeedbackVideo(id: videoID, exerciseName: "深蹲", setIndex: 0),
      text: "保持背部稳定", postedAt: Date())

    await model.open(item)

    #expect(model.selection?.id == videoID)
    #expect(model.selection?.url == url)
    #expect(model.selection?.badge?.setOrdinal == 1)
    #expect(model.resolvingFeedbackID == nil)
    #expect(model.failedFeedbackID == nil)
  }
}

private actor PlaybackMarkersRepository: VideoMarkerRepository {
  private var error: VideoMarkerRepositoryError?
  private let marker: VideoMarker

  init(error: VideoMarkerRepositoryError, marker: VideoMarker) {
    self.error = error
    self.marker = marker
  }

  func recover() { error = nil }

  func markers(videoID: UUID) async throws -> [VideoMarker] {
    if let error { throw error }
    return [marker]
  }

  func createMarker(videoID: UUID, timeMilliseconds: Int, level: VideoMarkerLevel, note: String)
    async throws -> VideoMarker
  {
    throw VideoMarkerRepositoryError.failed
  }

  func deleteMarker(videoID: UUID, markerID: UUID) async throws {
    throw VideoMarkerRepositoryError.failed
  }
}
