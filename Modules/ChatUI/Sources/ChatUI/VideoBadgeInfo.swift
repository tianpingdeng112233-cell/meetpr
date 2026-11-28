import Foundation

/// Display-ready training context rendered over a feedback video.
///
/// `setOrdinal` is intentionally not normalized here. Callers own the
/// zero-based-to-one-based boundary and pass the exact number users should see.
public struct VideoBadgeInfo: Equatable, Sendable {
  public let exerciseName: String?
  public let weightKg: Double?
  public let reps: Int?
  public let rpe: Double?
  public let setOrdinal: Int?

  public var hasContent: Bool {
    let presentation = VideoBadgePresentation(info: self, mode: .export)
    return presentation.exerciseName != nil || presentation.hasLoad || presentation.rpeText != nil
  }

  public init(
    exerciseName: String? = nil,
    weightKg: Double? = nil,
    reps: Int? = nil,
    rpe: Double? = nil,
    setOrdinal: Int? = nil
  ) {
    self.exerciseName = exerciseName
    self.weightKg = weightKg
    self.reps = reps
    self.rpe = rpe
    self.setOrdinal = setOrdinal
  }
}

struct VideoBadgePresentation: Equatable, Sendable {
  let exerciseName: String?
  let weightText: String?
  let reps: Int?
  let rpeText: String?
  let setOrdinal: Int?

  enum Mode { case replay, export }

  init(info: VideoBadgeInfo, mode: Mode) {
    exerciseName = Self.nonempty(info.exerciseName)
    weightText = Self.metricText(info.weightKg)
    reps = info.reps
    rpeText = Self.metricText(info.rpe)
    setOrdinal = mode == .replay ? info.setOrdinal : nil
  }

  var hasLoad: Bool {
    weightText != nil || reps != nil
  }

  private static func nonempty(_ value: String?) -> String? {
    guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty
    else {
      return nil
    }
    return value
  }

  private static func metricText(_ value: Double?) -> String? {
    guard let value, value.isFinite else { return nil }
    return value.formatted(
      .number
        .grouping(.never)
        .precision(.fractionLength(0...1))
        .locale(Locale(identifier: "en_US_POSIX"))
    )
  }
}
