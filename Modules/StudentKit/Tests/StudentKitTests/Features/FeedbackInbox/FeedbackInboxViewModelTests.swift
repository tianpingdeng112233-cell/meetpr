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
