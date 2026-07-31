import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import StudentKit

@MainActor
@Test func feedbackInboxViewModelTracksUnreadCountAndMarkRead() async throws {
  let repository = InMemoryStudentFeedbackRepository(
    seed: StudentDemoSeed.makeFeedback(),
    now: { StudentDemoSeed.referenceDate }
  )
  let viewModel = FeedbackInboxViewModel(repository: repository)

  await viewModel.load(studentID: StudentDemoSeed.studentID)
  #expect(viewModel.unreadCount == 2)

  let unread = try #require(viewModel.items.first { $0.readAt == nil })
  await viewModel.markRead(unread)

  #expect(viewModel.unreadCount == 1)
}

@MainActor
@Test func feedbackInboxOnlyReportsEmptyAfterSuccessfulLoad() async {
  let repository = EmptyStateFeedbackRepository()
  let viewModel = FeedbackInboxViewModel(repository: repository)

  #expect(!viewModel.hasFinishedLoading)
  #expect(!viewModel.isLoadedEmpty)

  let loadTask = Task { @MainActor in
    await viewModel.load(studentID: StudentDemoSeed.studentID)
  }
  while !(await repository.isWaiting) {
    await Task.yield()
  }

  #expect(viewModel.state == .loading)
  #expect(!viewModel.hasFinishedLoading)
  #expect(!viewModel.isLoadedEmpty)

  await repository.resolve(.success([]))
  await loadTask.value

  #expect(viewModel.hasFinishedLoading)
  #expect(viewModel.isLoadedEmpty)
}

@MainActor
@Test func feedbackInboxLoadFailureDoesNotMasqueradeAsEmpty() async {
  let repository = EmptyStateFeedbackRepository()
  let viewModel = FeedbackInboxViewModel(repository: repository)
  let loadTask = Task { @MainActor in
    await viewModel.load(studentID: StudentDemoSeed.studentID)
  }
  while !(await repository.isWaiting) {
    await Task.yield()
  }
  await repository.resolve(.failure(EmptyStateFeedbackError.failed))
  await loadTask.value

  guard case .error = viewModel.state else {
    Issue.record("Expected feedback error state, got \(viewModel.state)")
    return
  }
  #expect(!viewModel.hasFinishedLoading)
  #expect(!viewModel.isLoadedEmpty)
}

@MainActor
@Test func feedbackInboxRefreshKeepsLoadedContentVisible() async {
  let repository = EmptyStateFeedbackRepository()
  let viewModel = FeedbackInboxViewModel(repository: repository)

  let initialLoad = Task { @MainActor in
    await viewModel.load(studentID: StudentDemoSeed.studentID)
  }
  while !(await repository.isWaiting) {
    await Task.yield()
  }
  let items = StudentDemoSeed.makeFeedback()
  await repository.resolve(.success(items))
  await initialLoad.value

  let refresh = Task { @MainActor in
    await viewModel.load(studentID: StudentDemoSeed.studentID)
  }
  while !(await repository.isWaiting) {
    await Task.yield()
  }

  #expect(viewModel.state == .loaded(items))
  #expect(viewModel.items == items)

  await repository.resolve(.success(items))
  await refresh.value
}

@MainActor
@Test("video markers load, hide only when unavailable, and surface other failures")
func feedbackVideoMarkersDegradeByErrorKind() async throws {
  let videoID = UUID()
  let markerRepository = InMemoryVideoMarkerRepository(coachID: UUID())
  let created = try await markerRepository.createMarker(
    videoID: videoID,
    timeMilliseconds: 1_500,
    level: .warn,
    note: "Brace"
  )
  let available = FeedbackInboxViewModel(
    repository: InMemoryStudentFeedbackRepository(),
    markerRepository: markerRepository
  )
  let unavailable = FeedbackInboxViewModel(
    repository: InMemoryStudentFeedbackRepository(),
    markerRepository: FailingVideoMarkerRepository(error: .unavailable)
  )
  let failing = FeedbackInboxViewModel(
    repository: InMemoryStudentFeedbackRepository(),
    markerRepository: FailingVideoMarkerRepository(error: .failed)
  )
  let unknownError = FeedbackInboxViewModel(
    repository: InMemoryStudentFeedbackRepository(),
    markerRepository: FailingVideoMarkerRepository(error: nil)
  )

  #expect(await available.markers(videoID: videoID) == .loaded([created]))
  #expect(await unavailable.markers(videoID: videoID) == .hidden)
  #expect(await failing.markers(videoID: videoID) == .failed)
  // Fail safe: an error outside the repository's typed domain must surface,
  // not silently hide the coach's markers.
  #expect(await unknownError.markers(videoID: videoID) == .failed)
}

private enum EmptyStateFeedbackError: Error {
  case failed
}

private actor EmptyStateFeedbackRepository: StudentFeedbackRepository {
  private var continuation: CheckedContinuation<[CoachFeedback], any Error>?

  var isWaiting: Bool {
    continuation != nil
  }

  func resolve(_ result: Result<[CoachFeedback], EmptyStateFeedbackError>) {
    guard let continuation else { return }
    self.continuation = nil
    continuation.resume(with: result)
  }

  func fetchInbox(studentID: UUID) async throws -> [CoachFeedback] {
    try await withCheckedThrowingContinuation { continuation in
      self.continuation = continuation
    }
  }

  func postFeedback(
    studentID: UUID,
    dayDate: Date?,
    planExerciseID: UUID?,
    text: String
  ) async throws -> CoachFeedback {
    throw EmptyStateFeedbackError.failed
  }

  func markRead(feedbackID: UUID) async throws {}
}

private struct FailingVideoMarkerRepository: VideoMarkerRepository {
  /// `nil` throws an error outside the repository's typed domain — callers
  /// must fail safe and surface it rather than hide the marker surface.
  let error: VideoMarkerRepositoryError?

  private var thrown: any Error {
    error ?? EmptyStateFeedbackError.failed
  }

  func markers(videoID: UUID) async throws -> [VideoMarker] {
    throw thrown
  }

  func createMarker(
    videoID: UUID,
    timeMilliseconds: Int,
    level: VideoMarkerLevel,
    note: String
  ) async throws -> VideoMarker {
    throw thrown
  }

  func deleteMarker(videoID: UUID, markerID: UUID) async throws {
    throw thrown
  }
}
