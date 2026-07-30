import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import CoachKit

@Suite("Coach today todo ordering")
struct CoachTodayTodoListTests {
  @Test("orders videos, unread, missed training, then applications")
  // swiftlint:disable:next function_body_length
  func ordersActionableItems() {
    let now = Date(timeIntervalSince1970: 2_000_000)
    let attentionStudentID = UUID()
    let awaitingReplyStudentID = UUID()
    let items = CoachTodayTodoList.makeItems(
      videos: [
        pendingVideo(uploadedAt: now.addingTimeInterval(-600)),
        pendingVideo(uploadedAt: now.addingTimeInterval(-7_200)),
      ],
      conversations: [
        conversation(name: "李嘉宁", unreadCount: 2),
        conversation(name: "王晨曦", unreadCount: 1),
        conversation(name: "已读学员", unreadCount: 0),
      ],
      rosterRows: [
        row(
          id: attentionStudentID,
          name: "陈磊",
          signals: [.notTrained(daysMissed: 3), .awaitingReply]
        ),
        row(
          id: awaitingReplyStudentID,
          name: "只待回复",
          signals: [.awaitingReply]
        ),
      ],
      applications: [
        application(name: "新申请 A", submittedAt: now.addingTimeInterval(-900)),
        application(name: "新申请 B", submittedAt: now.addingTimeInterval(-3_600)),
      ],
      now: now
    )

    #expect(
      items.map(\.tag)
        == [
          CoachTodayStrings.awaitingFeedback,
          CoachTodayStrings.unread,
          CoachTodayStrings.needsAttention,
          CoachTodayStrings.newApplication,
        ]
    )
    #expect(items[0].title == CoachTodayStrings.pendingVideosTitle(2))
    #expect(items[0].subtitle == CoachTodayStrings.earliestVideoSubtitle("2 小时前"))
    #expect(items[1].title == CoachTodayStrings.unreadMessagesTitle(3))
    #expect(items[1].subtitle == "李嘉宁 · 王晨曦")
    #expect(
      items[2].title
        == CoachTodayStrings.notTrainedTitle(studentName: "陈磊", daysMissed: 3)
    )
    #expect(items[2].destination == .studentChat(attentionStudentID))
    #expect(items[3].title == CoachTodayStrings.multipleApplicationsTitle(2))
    #expect(
      items[3].subtitle
        == CoachTodayStrings.earliestApplicationSubtitle("已等待 1 小时")
    )
  }

  @Test("returns no rows when every source is empty or non-actionable")
  func emptyState() {
    let items = CoachTodayTodoList.makeItems(
      videos: [],
      conversations: [conversation(name: "已读学员", unreadCount: 0)],
      rosterRows: [row(id: UUID(), name: "待回复", signals: [.awaitingReply])],
      applications: [],
      now: Date()
    )

    #expect(items.isEmpty)
  }

  private func pendingVideo(uploadedAt: Date) -> PendingVideoItem {
    PendingVideoItem(
      id: UUID(),
      studentID: UUID(),
      studentDisplayName: "学员",
      uploadedAt: uploadedAt,
      sizeBytes: 1
    )
  }

  private func conversation(name: String, unreadCount: Int) -> ChatConversation {
    ChatConversation(
      id: UUID(),
      otherPartyID: UUID(),
      otherPartyName: name,
      lastMessagePreview: nil,
      lastMessageAt: nil,
      unreadCount: unreadCount,
      myLastRead: nil,
      otherLastRead: nil
    )
  }

  private func row(id: UUID, name: String, signals: [TriageSignal]) -> StudentRosterRowModel {
    StudentRosterRowModel(
      student: CoachStudentSummary(id: id, displayName: name, status: .active),
      lastActiveAt: nil,
      triageSignals: signals
    )
  }

  private func application(name: String, submittedAt: Date) -> CoachBindRequestItem {
    CoachBindRequestItem(
      id: UUID(),
      studentId: UUID(),
      displayName: name,
      submittedAt: submittedAt,
      expiredAt: submittedAt.addingTimeInterval(86_400),
      onboarding: CoachBindRequestOnboardingSummary(completed: false)
    )
  }
}
