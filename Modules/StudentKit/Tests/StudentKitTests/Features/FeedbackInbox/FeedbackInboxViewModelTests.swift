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

/// 走查 P1-3 回归 (spec 051 §2): 已读必须落在 repository 里 —
/// 重新 load 后仍是已读,不能只是被 markRead 刷新的内存态。
@MainActor
@Test func feedbackMarkReadSurvivesReload() async throws {
  let repository = InMemoryStudentFeedbackRepository(
    seed: StudentDemoSeed.makeFeedback(),
    now: { StudentDemoSeed.referenceDate }
  )
  let viewModel = FeedbackInboxViewModel(repository: repository)
  await viewModel.load(studentID: StudentDemoSeed.studentID)
  let unread = try #require(viewModel.items.first { $0.readAt == nil })
  await viewModel.markRead(unread)

  await viewModel.load(studentID: StudentDemoSeed.studentID)
  #expect(viewModel.unreadCount == 1)
  let reloaded = try #require(viewModel.items.first { $0.id == unread.id })
  #expect(reloaded.readAt != nil)
}
