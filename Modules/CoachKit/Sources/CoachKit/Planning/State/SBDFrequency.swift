import Foundation

public struct SBDFrequency: Equatable, Hashable, Sendable {
  public var squat: Int
  public var bench: Int
  public var deadlift: Int

  public init(squat: Int, bench: Int, deadlift: Int) {
    self.squat = squat
    self.bench = bench
    self.deadlift = deadlift
  }

  public static let empty = SBDFrequency(squat: 0, bench: 0, deadlift: 0)

  public var totalSessions: Int {
    squat + bench + deadlift
  }

  public var isWithinRange: Bool {
    [squat, bench, deadlift].allSatisfy { (0...7).contains($0) }
  }
}
