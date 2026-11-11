import Foundation

struct StudentTodayRefreshThrottle: Equatable, Sendable {
  enum Refresh: Equatable, Sendable {
    case full
    case volatileOnly
  }

  static let interval: TimeInterval = 25

  private(set) var lastFullRefreshAt: Date?

  init(lastFullRefreshAt: Date? = nil) {
    self.lastFullRefreshAt = lastFullRefreshAt
  }

  mutating func refreshWhenReturning(at date: Date) -> Refresh {
    guard let lastFullRefreshAt,
      date.timeIntervalSince(lastFullRefreshAt) < Self.interval
    else {
      self.lastFullRefreshAt = date
      return .full
    }
    return .volatileOnly
  }

  mutating func recordFullRefresh(at date: Date) {
    lastFullRefreshAt = date
  }
}
