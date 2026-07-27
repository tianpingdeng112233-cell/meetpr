import Foundation
import Testing

@testable import AppShell
@testable import CoachKit

@Test func dailyDigestRouteParsesCategoryAndUserInfoVariants() {
  #expect(
    PushNotificationRouteParser.route(
      categoryIdentifier: "coach_daily_digest",
      userInfo: [:]
    ) == .coachToday)
  #expect(
    PushNotificationRouteParser.route(
      categoryIdentifier: "",
      userInfo: ["event_type": "coach_daily_digest"]
    ) == .coachToday)
  #expect(
    PushNotificationRouteParser.route(
      categoryIdentifier: "",
      userInfo: ["aps": ["category": "coach_daily_digest"]]
    ) == .coachToday)
}

@Test func stagingDailyDigestPayloadRoutesToCoachToday() {
  let userInfo: [AnyHashable: Any] = [
    "aps": ["alert": ["title": "昨日训练摘要", "body": "昨天：3 练完"]],
    "counts": ["session_completed": 3],
    "gym_day": "2026-07-17",
  ]

  #expect(
    PushNotificationRouteParser.route(
      categoryIdentifier: "",
      userInfo: userInfo
    ) == .coachToday)
}

@Test func unrelatedNotificationDoesNotSelectCoachTab() {
  #expect(
    PushNotificationRouteParser.route(
      categoryIdentifier: "plan_published",
      userInfo: ["event_type": "plan_published"]
    ) == nil)
}

@MainActor
@Test func parsedRouteSelectsActualCoachTodayTab() throws {
  let selection = CoachTabSelection(selectedTab: .students)
  let navigation = AppNavigationModel(coachTabSelection: selection)
  let route = PushNotificationRouteParser.route(
    categoryIdentifier: "coach_daily_digest",
    userInfo: [:]
  )

  navigation.open(try #require(route))

  #expect(selection.selectedTab == .today)
}
