import CoreModels
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
  /// `setIndex` is rendered as-is: `set_logs.set_index` is already 1-based
  /// (it is projected from `plan_sets.set_number`, which the database pins to
  /// `>= 1`), and plan-web prints the same field verbatim. Adding one here
  /// would show the coach and the student different set numbers for one clip.
  static func summary(_ video: CoachFeedbackVideo) -> String {
    [
      video.exerciseName,
      video.setIndex.map { "第\($0)组" },
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
