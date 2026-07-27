import CoreModels
import DesignSystem
import Foundation

enum FeedbackVideoAssociation: Equatable, Sendable {
  case none
  case available(CoachFeedbackVideo)
  case unavailable
}

enum FeedbackVideoPresentation {
  static func association(
    videoID: UUID?,
    video: CoachFeedbackVideo?
  ) -> FeedbackVideoAssociation {
    if let video { return .available(video) }
    if videoID != nil { return .unavailable }
    return .none
  }

  /// Every part is optional and drops out cleanly, so a freely recorded clip
  /// with no set log still gets a usable card instead of "第0组 · kg×次".
  ///
  /// `setIndex` comes from the linked `set_logs.set_index` and remains
  /// zero-based until this display boundary.
  static func summary(_ video: CoachFeedbackVideo) -> String {
    [
      video.exerciseName,
      video.setIndex.map {
        "第\(SetIndexDisplay.number(forZeroBasedIndex: $0))组"
      },
      load(weightKg: video.weightKg, reps: video.reps),
    ]
    .compactMap { $0 }
    .joined(separator: " · ")
  }

  static func load(weightKg: String?, reps: Int?) -> String? {
    switch (weightKg, reps) {
    case (let loadKg?, let reps?): "\(weight(loadKg))kg×\(reps)次"
    case (let loadKg?, nil): "\(weight(loadKg))kg"
    case (nil, let reps?): "\(reps)次"
    case (nil, nil): nil
    }
  }

  static func weight(_ rawValue: String) -> String {
    guard rawValue.contains(".") else { return rawValue }
    let withoutZeros = rawValue.reversed().drop(while: { $0 == "0" }).reversed()
    if withoutZeros.last == "." {
      return String(withoutZeros.dropLast())
    }
    return String(withoutZeros)
  }
}
