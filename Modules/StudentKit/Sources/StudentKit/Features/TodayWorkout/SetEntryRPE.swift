import CoreGraphics
import Foundation

/// Pure RPE scale contract from `SE_RIR` and `seTicks`.
enum SetEntryRPE {
  static let minValue = 5.0
  static let maxValue = 10.0
  static let step = 0.5
  static let cellCount = 11

  static let descriptions = [
    "还能多做 5 次",
    "还能多做 4-5 次",
    "还能多做 4 次",
    "还能多做 3-4 次",
    "还能多做 3 次",
    "还能多做 2-3 次",
    "还能多做 2 次",
    "还能多做 1-2 次",
    "还能多做 1 次",
    "或许还能多做 1 次",
    "力竭，无保留",
  ]

  static func snap(_ value: Double) -> Double {
    min(maxValue, max(minValue, (value * 2).rounded() / 2))
  }

  static func index(for value: Double) -> Int {
    Int(((snap(value) - minValue) / step).rounded())
  }

  /// Width of one tick cell: the strip lays out `cellCount` equal cells with
  /// `spacing` between them, so the gaps have to come off the top before the
  /// remainder is split.
  static func cellWidth(width: Double, spacing: Double) -> Double {
    (width - spacing * Double(cellCount - 1)) / Double(cellCount)
  }

  /// Centre of tick `index` in strip coordinates — where the bar is actually
  /// drawn, and therefore what a hit test has to measure against.
  static func centerX(ofIndex index: Int, width: Double, spacing: Double) -> Double {
    let cell = cellWidth(width: width, spacing: spacing)
    guard cell > 0 else { return 0 }
    return cell / 2 + Double(index) * (cell + spacing)
  }

  /// Nearest-tick hit test for a touch at `x`. Rounds to the closest bar centre
  /// (the old version floored a spacing-blind 11-way split of the full width,
  /// which put every bucket boundary 1–3pt off the bar the student was aiming
  /// at), clamped to the ends.
  static func value(atX x: Double, width: Double, spacing: Double) -> Double {
    // A strip too narrow to hold 11 cells plus its gaps has no real geometry to
    // hit-test against — `cellWidth` would go negative while `pitch` stayed
    // positive, quietly returning stops that don't line up with the HStack.
    let cell = cellWidth(width: width, spacing: spacing)
    guard width > 0, cell > 0 else { return minValue }
    let raw = ((x - cell / 2) / (cell + spacing)).rounded()
    let index = min(Double(cellCount - 1), max(0, raw))
    return minValue + index * step
  }

  /// What a finger-down on the strip turned out to mean. Decided once per
  /// gesture, past `intentThreshold`, and then held: a scrub that later curves
  /// vertically keeps scrubbing, and a scroll never comes back to write a value.
  enum ScrubIntent: Equatable {
    case idle
    case scrub
    case scroll
  }

  /// Points of travel before a gesture commits to being a scrub or a scroll.
  /// A touch that never gets this far is a tap, handled by the same gesture's
  /// release branch — the strip has exactly one path to the binding.
  static let intentThreshold = 6.0

  /// Whether releasing should write a value. Only a gesture that never became
  /// anything — a tap — writes on release; a scrub has already written live,
  /// and a scroll must never write at all. This reads the *locked* intent, not
  /// the final translation: a scroll that wanders back to its start point ends
  /// with zero displacement but is still a scroll.
  static func commitsOnRelease(intent: ScrubIntent) -> Bool {
    intent == .idle
  }

  static func intent(forTranslation translation: CGSize, threshold: Double = intentThreshold)
    -> ScrubIntent
  {
    let horizontal = abs(translation.width)
    let vertical = abs(translation.height)
    guard max(horizontal, vertical) >= threshold else { return .idle }
    return horizontal >= vertical ? .scrub : .scroll
  }

  /// The lock itself: once a gesture has committed to a meaning it keeps it for
  /// the rest of its life. Re-deriving from `translation` every frame is wrong
  /// in both directions — a scroll that drifts sideways would start writing RPE,
  /// and a scrub dragged back to where it started would read as a fresh tap.
  static func lockedIntent(current: ScrubIntent, translation: CGSize) -> ScrubIntent {
    current == .idle ? intent(forTranslation: translation) : current
  }

  static func description(_ value: Double) -> String {
    descriptions[Int(((snap(value) - minValue) * 2).rounded())]
  }

  static func text(_ value: Double) -> String {
    snap(value).formatted(.number.precision(.fractionLength(1)))
  }

  static func barHeight(for value: Double, selectedValue: Double) -> CGFloat {
    if abs(value - snap(selectedValue)) < 0.01 {
      return 32
    }
    return value.truncatingRemainder(dividingBy: 1) == 0 ? 22 : 13
  }

  static func isLit(_ value: Double, selectedValue: Double) -> Bool {
    value <= snap(selectedValue) + 0.01
  }
}
