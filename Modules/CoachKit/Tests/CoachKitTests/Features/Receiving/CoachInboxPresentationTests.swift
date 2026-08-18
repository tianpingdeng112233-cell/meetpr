import ChatUI
import CoreModels
import Foundation
import Testing

@testable import CoachKit

@Test func coachInboxIsEmptyOnlyWhenBothSourcesAreEmpty() {
  #expect(
    CoachInboxPresentation.rows(conversations: [], videoGroups: [], now: .distantPast).isEmpty)
  #expect(CoachInboxPresentation.count(conversations: [], pendingVideoCount: 0) == 0)
}

@Test func coachInboxUnifiesChatAndVideoStudentsWithoutDuplicates() throws {
  let now = Date(timeIntervalSince1970: 1_800_000_000)
  let sharedStudentID = UUID(uuidString: "04200000-0000-0000-0000-000000000001")!
  let chatOnlyStudentID = UUID(uuidString: "04200000-0000-0000-0000-000000000002")!
  let videoOnlyStudentID = UUID(uuidString: "04200000-0000-0000-0000-000000000003")!
  let conversations = [
    conversation(
      studentID: sharedStudentID,
      name: "",
      unreadCount: 2,
      timestamp: now.addingTimeInterval(-120)
    ),
    conversation(
      studentID: chatOnlyStudentID,
      name: "仅消息学员",
      unreadCount: 1,
      timestamp: now.addingTimeInterval(-30)
    ),
  ]
  let groups = [
    PendingVideoStudentGroup(
      studentID: sharedStudentID,
      studentName: "共享学员",
      count: 3,
      latestUploadedAt: now.addingTimeInterval(-60)
    ),
    PendingVideoStudentGroup(
      studentID: videoOnlyStudentID,
      studentName: "仅视频学员",
      count: 1,
      latestUploadedAt: now.addingTimeInterval(-10)
    ),
  ]

  let rows = CoachInboxPresentation.rows(
    conversations: conversations,
    videoGroups: groups,
    now: now
  )

  #expect(rows.count == 3)
  let shared = try #require(rows.first { $0.studentID == sharedStudentID })
  assertUnifiedRow(shared, now: now)
}

@Test func coachInboxPrioritizesVideosThenUnreadThenRecency() {
  let now = Date(timeIntervalSince1970: 1_800_000_000)
  let videoAndUnreadID = UUID(uuidString: "04200000-0000-0000-0000-000000000011")!
  let videoOnlyID = UUID(uuidString: "04200000-0000-0000-0000-000000000012")!
  let unreadOnlyID = UUID(uuidString: "04200000-0000-0000-0000-000000000013")!
  let quietID = UUID(uuidString: "04200000-0000-0000-0000-000000000014")!

  let rows = CoachInboxPresentation.rows(
    conversations: [
      conversation(
        studentID: videoAndUnreadID,
        name: "双提醒",
        unreadCount: 1,
        timestamp: now.addingTimeInterval(-600)
      ),
      conversation(
        studentID: unreadOnlyID,
        name: "未读",
        unreadCount: 1,
        timestamp: now.addingTimeInterval(-10)
      ),
      conversation(
        studentID: quietID,
        name: "普通",
        unreadCount: 0,
        timestamp: now
      ),
    ],
    videoGroups: [
      PendingVideoStudentGroup(
        studentID: videoAndUnreadID,
        studentName: "双提醒",
        count: 1,
        latestUploadedAt: now.addingTimeInterval(-700)
      ),
      PendingVideoStudentGroup(
        studentID: videoOnlyID,
        studentName: "视频",
        count: 1,
        latestUploadedAt: now.addingTimeInterval(-20)
      ),
    ],
    now: now
  )

  #expect(rows.map(\.studentID) == [videoAndUnreadID, videoOnlyID, unreadOnlyID, quietID])
}

@Test func coachInboxUsesStudentIDAsStableTieBreakerForSameName() {
  let firstID = UUID(uuidString: "04200000-0000-0000-0000-000000000021")!
  let secondID = UUID(uuidString: "04200000-0000-0000-0000-000000000022")!

  let rows = CoachInboxPresentation.rows(
    conversations: [
      conversation(studentID: secondID, name: "同名", unreadCount: 0, timestamp: nil),
      conversation(studentID: firstID, name: "同名", unreadCount: 0, timestamp: nil),
    ],
    videoGroups: [],
    now: .distantPast
  )

  #expect(rows.map(\.studentID) == [firstID, secondID])
}

@Test func coachInboxCoalescesDuplicateStudentConversationsToTheLatest() throws {
  let studentID = UUID(uuidString: "04200000-0000-0000-0000-000000000023")!
  let earlier = Date(timeIntervalSince1970: 1_700_000_000)
  let later = earlier.addingTimeInterval(60)
  let rows = CoachInboxPresentation.rows(
    conversations: [
      conversation(
        studentID: studentID,
        name: "旧会话",
        unreadCount: 7,
        timestamp: earlier
      ),
      conversation(
        studentID: studentID,
        name: "新会话",
        unreadCount: 2,
        timestamp: later
      ),
    ],
    videoGroups: [],
    now: later
  )

  let row = try #require(rows.first)
  #expect(rows.count == 1)
  #expect(row.studentName == "新会话")
  #expect(row.unreadCount == 2)
  #expect(row.latestActivityAt == later)
  #expect(
    CoachInboxPresentation.count(
      conversations: [
        conversation(
          studentID: studentID,
          name: "旧会话",
          unreadCount: 7,
          timestamp: earlier
        ),
        conversation(
          studentID: studentID,
          name: "新会话",
          unreadCount: 2,
          timestamp: later
        ),
      ],
      pendingVideoCount: 1
    ) == 3
  )
}

@Test func coachInboxCountAddsPendingVideosAndUnreadMessages() {
  let conversations = [
    conversation(studentID: UUID(), name: "甲", unreadCount: 2, timestamp: nil),
    conversation(studentID: UUID(), name: "乙", unreadCount: 3, timestamp: nil),
  ]

  #expect(CoachInboxPresentation.count(conversations: conversations, pendingVideoCount: 4) == 9)
}

@Test func coachDemoInboxUsesRosterIDsWithoutDuplicateStudents() throws {
  let now = Date(timeIntervalSince1970: 1_800_000_000)
  let seed = ChatDemoSeed.coach()
  let videoItems = CoachDemoSeed.pendingVideos(now: now)
  let videoGroups = Dictionary(grouping: videoItems, by: \.studentID).map { entry in
    let studentID = entry.key
    let items = entry.value
    return PendingVideoStudentGroup(
      studentID: studentID,
      studentName: items[0].studentDisplayName,
      count: items.count,
      latestUploadedAt: items.map(\.uploadedAt).max() ?? now
    )
  }

  let rows = CoachInboxPresentation.rows(
    conversations: seed.conversations,
    videoGroups: videoGroups,
    now: now
  )

  #expect(rows.count == 3)
  let wangID = CoachDemoSeed.previewStudentID(4)
  let liID = CoachDemoSeed.previewStudentID(8)
  let zhangID = CoachDemoSeed.previewStudentID(2)
  let expectedNames = Dictionary(
    uniqueKeysWithValues: seed.conversations.map { ($0.otherPartyID, $0.otherPartyName) }
  )
  #expect(Set(rows.map(\.studentID)) == [wangID, liID, zhangID])
  #expect(rows.first { $0.studentID == wangID }?.studentName == expectedNames[wangID])
  #expect(rows.first { $0.studentID == wangID }?.pendingVideoCount == 3)
  #expect(rows.first { $0.studentID == wangID }?.unreadCount == 1)
  #expect(rows.first { $0.studentID == liID }?.studentName == expectedNames[liID])
  #expect(rows.first { $0.studentID == liID }?.pendingVideoCount == 2)
  #expect(rows.first { $0.studentID == liID }?.unreadCount == 1)
  #expect(rows.first { $0.studentID == zhangID }?.pendingVideoCount == 1)
}

private func conversation(
  studentID: UUID,
  name: String,
  unreadCount: Int,
  timestamp: Date?
) -> ChatConversation {
  ChatConversation(
    id: UUID(),
    otherPartyID: studentID,
    otherPartyName: name,
    lastMessagePreview: "最近消息",
    lastMessageAt: timestamp,
    unreadCount: unreadCount,
    myLastRead: nil,
    otherLastRead: nil
  )
}

private func assertUnifiedRow(_ row: CoachInboxRow, now: Date) {
  #expect(row.studentName == "共享学员")
  #expect(row.unreadCount == 2)
  #expect(row.pendingVideoCount == 3)
  #expect(row.conversation != nil)
  #expect(row.videoGroup != nil)
  #expect(
    row.lastPreview
      == CoachInboxStrings.pendingVideoPreview(
        count: 3,
        relativeTime: CoachStudentFormatting.relativeText(
          now.addingTimeInterval(-60),
          now: now
        )
      )
  )
}
