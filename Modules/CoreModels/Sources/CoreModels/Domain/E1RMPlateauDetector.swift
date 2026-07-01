import Foundation

/// Detects whether a lift's estimated-1RM has stopped meaningfully improving —
/// the "plateau / adaptation resistance" signal for the coach analytics A-group
/// (e1RM 轨迹 + 平台). Pure cross-role domain math, alongside `E1RMCalculator`.
///
/// Methodology: a competition-lift e1RM that flattens despite maintained
/// volume/effort is the cue to rotate variations (directed adaptation vs
/// adaptation resistance). It is a SOFT signal (a coach-facing banner cue),
/// never a hard gate. See
/// `~/Brain/wiki/projects/MeetPR/domain/coach-analytics-v1-scope.md` §2 and
/// `powerlifting/weakness-diagnosis-and-variations.md`.
///
/// "Plateau" = the athlete's running-best e1RM has not been beaten by at least
/// `minGainKg` for at least `minStallWeeks`, given at least `minPoints`
/// observations (so a cold start is never called a plateau).
public enum E1RMPlateauDetector {
  /// A single e1RM observation for one lift/variation. The caller computes
  /// `e1RMKg` (typically via `E1RMCalculator`) and supplies the source date.
  public struct Point: Equatable, Sendable {
    public let date: Date
    public let e1RMKg: Double

    public init(date: Date, e1RMKg: Double) {
      self.date = date
      self.e1RMKg = e1RMKg
    }
  }

  public struct Result: Equatable, Sendable {
    public let isPlateau: Bool
    /// Whole weeks since the last meaningful gain (0 when too few points).
    public let weeksStalled: Int
    /// Running-best (all-time max) e1RM across the supplied points.
    public let bestE1RMKg: Double?
    /// Date of the last point that beat the running best by `minGainKg`.
    public let lastGainAt: Date?

    public init(isPlateau: Bool, weeksStalled: Int, bestE1RMKg: Double?, lastGainAt: Date?) {
      self.isPlateau = isPlateau
      self.weeksStalled = weeksStalled
      self.bestE1RMKg = bestE1RMKg
      self.lastGainAt = lastGainAt
    }

    public static let none = Result(
      isPlateau: false, weeksStalled: 0, bestE1RMKg: nil, lastGainAt: nil)
  }

  /// - Parameters:
  ///   - points: e1RM observations for ONE lift/variation, any order.
  ///   - minGainKg: smallest increase counted as progress (default 2.5kg, the
  ///     smallest common plate jump). Sub-threshold creep raises the bar to
  ///     beat but is not itself a "gain".
  ///   - minStallWeeks: weeks without a meaningful gain before it is a plateau.
  ///   - minPoints: fewest observations needed to judge.
  public static func detect(
    points: [Point],
    minGainKg: Double = 2.5,
    minStallWeeks: Int = 4,
    minPoints: Int = 4
  ) -> Result {
    let sorted = points.sorted { $0.date < $1.date }
    guard let first = sorted.first, let last = sorted.last else { return .none }

    var runningBest = first.e1RMKg
    var lastGainAt = first.date
    for point in sorted.dropFirst() {
      if point.e1RMKg >= runningBest + minGainKg {
        runningBest = point.e1RMKg
        lastGainAt = point.date
      } else if point.e1RMKg > runningBest {
        runningBest = point.e1RMKg
      }
    }

    let stallDays = max(0, last.date.timeIntervalSince(lastGainAt) / 86_400)
    let weeksStalled = Int(stallDays / 7)
    let isPlateau = sorted.count >= minPoints && weeksStalled >= minStallWeeks
    return Result(
      isPlateau: isPlateau,
      weeksStalled: weeksStalled,
      bestE1RMKg: runningBest,
      lastGainAt: lastGainAt
    )
  }
}
