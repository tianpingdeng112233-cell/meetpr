import Observation

public enum CoachTab: Hashable, Sendable {
  case today
  case students
  case planning
  case receiving
  case profile
}

@Observable
@MainActor
@available(iOS 17.0, macOS 14.0, *)
public final class CoachTabSelection {
  public internal(set) var selectedTab: CoachTab

  public init(selectedTab: CoachTab = .today) {
    self.selectedTab = selectedTab
  }

  public func select(_ tab: CoachTab) {
    selectedTab = tab
  }
}
