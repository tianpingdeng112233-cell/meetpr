import ChatUI
import Foundation

enum SetEntryVideoDetails {
  static func text(_ badge: VideoBadgeInfo) -> String {
    var parts: [String] = []
    if let number = badge.setOrdinal {
      parts.append(StudentStrings.replacing(.setEntryVideoSet, values: [String(number)]))
    }
    let weight = badge.weightKg.flatMap { $0.isFinite ? metric($0) + "kg" : nil }
    let reps = badge.reps.map { String($0) }
    let load = [weight, reps].compactMap { $0 }.joined(separator: " × ")
    if !load.isEmpty { parts.append(load) }
    if let rpe = badge.rpe, rpe.isFinite { parts.append("RPE " + metric(rpe)) }
    return parts.joined(separator: " · ")
  }

  private static func metric(_ value: Double) -> String {
    value.formatted(
      .number.grouping(.never).precision(.fractionLength(0...1))
        .locale(Locale(identifier: "en_US_POSIX")))
  }

}
