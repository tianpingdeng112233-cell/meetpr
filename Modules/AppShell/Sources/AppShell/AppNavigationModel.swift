import CoachKit
import Foundation

public enum AppRoute: Equatable, Sendable {
  case coachToday
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
public final class AppNavigationModel {
  public let coachTabSelection: CoachTabSelection

  public init(coachTabSelection: CoachTabSelection = CoachTabSelection()) {
    self.coachTabSelection = coachTabSelection
  }

  public func open(_ route: AppRoute) {
    switch route {
    case .coachToday:
      coachTabSelection.select(.today)
    }
  }
}

public enum PushNotificationRouteParser {
  public static func route(
    categoryIdentifier: String,
    userInfo: [AnyHashable: Any]
  ) -> AppRoute? {
    let eventNames = [
      categoryIdentifier,
      stringValue(for: "event_type", in: userInfo),
      stringValue(for: "eventType", in: userInfo),
      stringValue(for: "category", in: userInfo),
      apsCategory(in: userInfo),
    ]

    if eventNames.contains("coach_daily_digest") {
      return .coachToday
    }

    // Backend spec 019's staging payload predates an explicit category. Its
    // root-level digest fields are still a stable discriminator, alongside
    // the standard `aps` dictionary supplied by APNs.
    if userInfo["counts"] != nil,
      userInfo["gym_day"] is String,
      userInfo["aps"] != nil
    {
      return .coachToday
    }

    return nil
  }

  private static func stringValue(
    for key: String,
    in userInfo: [AnyHashable: Any]
  ) -> String {
    userInfo[key] as? String ?? ""
  }

  private static func apsCategory(in userInfo: [AnyHashable: Any]) -> String {
    guard let aps = userInfo["aps"] as? [AnyHashable: Any] else {
      return ""
    }
    return aps["category"] as? String ?? ""
  }
}
