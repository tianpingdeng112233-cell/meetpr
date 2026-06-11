import Foundation
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
