import CoreModels
import Foundation
import RepositoryContracts
import SwiftUI
import Testing
import ViewInspector

@testable import StudentKit

@MainActor
struct FeedbackVideoPlaybackInteractionTests {
  @Test func onlyTheVideoCoverStartsPlayback() async throws {
    let item = makeFeedback()
    let videoID = try #require(item.videoID)
    let url = try #require(URL(string: "https://example.com/clip.mp4"))
    let feedback = FeedbackInboxViewModel(
      repository: InMemoryStudentFeedbackRepository(playbackURLs: [videoID: url]))
    let playback = FeedbackVideoPlaybackModel(feedback: feedback)
    let card = StudentFeedbackChatCard(
      feedback: item, model: feedback, isVisible: true, playback: playback)
    let buttons = try card.inspect().findAll(ViewType.Button.self)
    #expect(buttons.count == 1)
    let button = try #require(buttons.first)
    #expect((try? button.labelView().find(text: item.text)) == nil)

    try button.tap()
    try await waitUntilOnMain { playback.selection != nil }

    #expect(playback.selection?.id == videoID)
    #expect(playback.selection?.url == url)
  }

  @Test(arguments: [false, true])
  func textAndMissingVideosHaveNoPlaybackButton(hasVideoID: Bool) throws {
    let item = makeFeedback(videoID: hasVideoID ? UUID() : nil, hasVideo: false)
    let feedback = FeedbackInboxViewModel(repository: InMemoryStudentFeedbackRepository())
    let card = StudentFeedbackChatCard(
      feedback: item, model: feedback, isVisible: true,
      playback: FeedbackVideoPlaybackModel(feedback: feedback))

    #expect(try card.inspect().findAll(ViewType.Button.self).isEmpty)
    #expect(throws: Never.self) { try card.inspect().find(text: item.text) }
  }

  @Test func repeatedTapAndLeavingChatCannotOpenALateVideo() async throws {
    let item = makeFeedback()
    let repository = ControlledFeedbackPlaybackRepository()
    let model = FeedbackVideoPlaybackModel(
      feedback: FeedbackInboxViewModel(repository: repository))
    var requests = repository.requests.makeAsyncIterator()
    let first = Task { await model.open(item) }
    #expect(await requests.next() == item.videoID)
    #expect(model.resolvingFeedbackID == item.id)
    await model.open(item)
    #expect(await repository.requestCount == 1)

    model.cancel()
    await repository.resolve(.success(URL(fileURLWithPath: "/cancelled.mp4")))
    await first.value

    #expect(model.selection == nil)
    #expect(model.resolvingFeedbackID == nil)
    #expect(model.failedFeedbackID == nil)
  }

  @Test func failedLinkCanBeRetried() async throws {
    let item = makeFeedback()
    let repository = ControlledFeedbackPlaybackRepository()
    let model = FeedbackVideoPlaybackModel(
      feedback: FeedbackInboxViewModel(repository: repository))
    var requests = repository.requests.makeAsyncIterator()
    let first = Task { await model.open(item) }
    _ = await requests.next()
    await repository.resolve(.failure(.videoPlaybackUnavailable))
    await first.value
    #expect(model.selection == nil)
    #expect(model.failedFeedbackID == item.id)
    #expect(model.resolvingFeedbackID == nil)

    let retry = Task { await model.open(item) }
    _ = await requests.next()
    let url = URL(fileURLWithPath: "/retry.mp4")
    await repository.resolve(.success(url))
    await retry.value
    #expect(model.selection?.url == url)
    #expect(model.failedFeedbackID == nil)

    let renewal = Task { try await model.freshURL(videoID: try #require(item.videoID)) }
    #expect(await requests.next() == item.videoID)
    let renewedURL = URL(fileURLWithPath: "/renewed.mp4")
    await repository.resolve(.success(renewedURL))
    #expect(try await renewal.value == renewedURL)
  }

  private func makeFeedback(videoID: UUID? = UUID(), hasVideo: Bool = true) -> CoachFeedback {
    CoachFeedback(
      id: UUID(), coachID: UUID(), studentID: UUID(), videoID: videoID,
      video: hasVideo ? videoID.map { CoachFeedbackVideo(id: $0) } : nil,
      text: "保持背部稳定", postedAt: Date())
  }
}

private actor ControlledFeedbackPlaybackRepository: StudentFeedbackRepository {
  nonisolated let requests: AsyncStream<UUID>
  private let started: AsyncStream<UUID>.Continuation
  private var pending: CheckedContinuation<URL, any Error>?
  private(set) var requestCount = 0

  init() {
    let stream = AsyncStream<UUID>.makeStream()
    requests = stream.stream
    started = stream.continuation
  }

  func playbackURL(videoID: UUID) async throws -> URL {
    requestCount += 1
    return try await withCheckedThrowingContinuation { continuation in
      pending = continuation
      started.yield(videoID)
    }
  }

  func resolve(_ result: Result<URL, StudentFeedbackRepositoryError>) {
    let continuation = pending
    pending = nil
    continuation?.resume(with: result)
  }

  func fetchInbox(studentID: UUID) async throws -> [CoachFeedback] { [] }
  func markRead(feedbackID: UUID) async throws {}
  func postFeedback(studentID: UUID, dayDate: Date?, planExerciseID: UUID?, text: String)
    async throws -> CoachFeedback
  {
    throw StudentFeedbackRepositoryError.videoPlaybackUnavailable
  }
}
