import Foundation
import Testing

@testable import ChatUI

@Suite struct ChatTimestampSeparatorTests {
  @Test func groupsFirstAndFiveMinuteGapsAndRecomputesHistoryBoundary() throws {
    let now = try Date("2026-11-06T19:34:00Z", strategy: .iso8601)
    let dates = [0.0, 299, 599, 600].map { now.addingTimeInterval($0) }
    let separators = ChatRelativeTime.separators(
      timestamps: dates, now: now, locale: Locale(identifier: "en_GB"))
    #expect(separators.keys.sorted() == [0, 2])
    let prepended = [now.addingTimeInterval(-60)] + dates
    #expect(
      ChatRelativeTime.separators(
        timestamps: prepended, now: now, locale: Locale(identifier: "en_GB")
      ).keys.sorted() == [0, 3])
    #expect(ChatRelativeTime.separators(timestamps: [], now: now, locale: .current).isEmpty)
  }
  @Test func fiveDateBucketsUseLocalCalendarAndLocaleClock() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(secondsFromGMT: 0))
    let now = try Date("2026-11-06T20:00:00Z", strategy: .iso8601)
    let dates = try ["2025-11-03", "2026-10-03", "2026-11-04", "2026-11-05", "2026-11-06"]
      .map { try Date("\($0)T19:34:00Z", strategy: .iso8601) }
    let chinese = ChatRelativeTime.separators(
      timestamps: dates, now: now, locale: Locale(identifier: "zh_CN"), calendar: calendar)
    #expect(chinese[0] == "2025年11月3日 19:34")
    #expect(chinese[1] == "10月3日 19:34")
    #expect(chinese[2] == "周三 19:34")
    #expect(chinese[3] == "昨天 19:34")
    #expect(chinese[4] == "19:34")
    let english = ChatRelativeTime.separators(
      timestamps: dates, now: now, locale: Locale(identifier: "en_US"), calendar: calendar)
    #expect(english[0] == "Nov 3, 2025 7:34\u{202F}PM")
    #expect(english[1] == "Oct 3 7:34\u{202F}PM")
    #expect(english[2] == "Wed 7:34\u{202F}PM")
    #expect(english[3] == "Yesterday 7:34\u{202F}PM")
    #expect(english[4] == "7:34\u{202F}PM")
  }
  @Test func localMidnightAndSevenDayBoundaryUseCalendarDays() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try #require(TimeZone(identifier: "America/Los_Angeles"))
    let now = try Date("2026-11-06T08:10:00Z", strategy: .iso8601)
    let yesterday = try Date("2026-11-06T07:55:00Z", strategy: .iso8601)
    #expect(
      ChatRelativeTime.separatorText(
        yesterday, now: now, locale: Locale(identifier: "en_GB"), calendar: calendar
      ) == "Yesterday 23:55")
    let sevenDaysAgo = try Date("2026-10-30T19:34:00Z", strategy: .iso8601)
    #expect(
      ChatRelativeTime.separatorText(
        sevenDaysAgo, now: now, locale: Locale(identifier: "en_US"), calendar: calendar
      ) == "Oct 30 12:34\u{202F}PM")
  }

}

@MainActor
@Test func pendingMessagesUseLocalSendTimeAndKeepItAcrossRetry() async throws {
  let repository = TestChatRepository()
  await repository.enqueueTextSend(.failure)
  let coordinator = ChatSendCoordinator(repository: repository, currentUserID: UUID())
  let conversationID = UUID()
  let before = Date()
  let clientID = coordinator.sendText(in: conversationID, text: "hello")
  let item = try #require(coordinator.outbox(in: conversationID).first)
  #expect(item.createdAt >= before)
  #expect(item.createdAt <= Date())
  let separators = ChatRelativeTime.separators(
    timestamps: [item.createdAt.addingTimeInterval(-300), item.createdAt],
    now: item.createdAt, locale: .current)
  #expect(separators.keys.sorted() == [0, 1])
  let failed = await chatEventually {
    await MainActor.run {
      if case .failed = coordinator.outbox(in: conversationID).first?.state { return true }
      return false
    }
  }
  #expect(failed)
  coordinator.retry(in: conversationID, clientID: clientID)
  #expect(coordinator.outbox(in: conversationID).first?.createdAt == item.createdAt)
  await coordinator.cancelAllAndWaitForCleanup()
  #expect(!clientID.isEmpty)
}
