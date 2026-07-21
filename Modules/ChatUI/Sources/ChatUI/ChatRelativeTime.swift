import Foundation

/// Chinese-only relative timestamps for chat surfaces.
///
/// The app ships a single language: `MeetPR/Resources/Localizable.xcstrings` is
/// empty and every existing screen hardcodes Chinese. SwiftUI's
/// `Text(date, style: .relative)` follows the *device* locale instead, so on a
/// non-Chinese simulator it renders "7 min, 39 secs" in the middle of a Chinese
/// list. This mirrors `CoachKit`'s `CoachStudentFormatting.relativeText` — ChatUI
/// cannot import CoachKit (ADR-005), hence the small duplicate.
enum ChatRelativeTime {
  static func text(_ date: Date, now: Date = Date()) -> String {
    let seconds = max(0, Int(now.timeIntervalSince(date)))
    if seconds < 60 {
      return "刚刚"
    }
    if seconds < 3_600 {
      return "\(seconds / 60) 分钟前"
    }
    if seconds < 86_400 {
      return "\(seconds / 3_600) 小时前"
    }
    if seconds < 2_592_000 {
      return "\(seconds / 86_400) 天前"
    }
    if seconds < 31_536_000 {
      return "\(seconds / 2_592_000) 个月前"
    }
    return "\(seconds / 31_536_000) 年前"
  }
}
