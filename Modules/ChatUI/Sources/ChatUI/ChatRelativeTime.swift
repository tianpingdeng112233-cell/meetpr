import Foundation

/// Stable relative timestamps for chat surfaces.
///
/// SwiftUI's `Text(date, style: .relative)` includes seconds and does not match
/// the product's minute/hour/day buckets, so ChatUI keeps the bucket logic and
/// localizes the resulting labels inside its own bundle.
enum ChatRelativeTime {
  static func text(_ date: Date, now: Date = Date()) -> String {
    let seconds = max(0, Int(now.timeIntervalSince(date)))
    if seconds < 60 {
      return ChatStrings.justNow
    }
    if seconds < 3_600 {
      return ChatStrings.minutesAgo(seconds / 60)
    }
    if seconds < 86_400 {
      return ChatStrings.hoursAgo(seconds / 3_600)
    }
    if seconds < 2_592_000 {
      return ChatStrings.daysAgo(seconds / 86_400)
    }
    if seconds < 31_536_000 {
      return ChatStrings.monthsAgo(seconds / 2_592_000)
    }
    return ChatStrings.yearsAgo(seconds / 31_536_000)
  }
}
