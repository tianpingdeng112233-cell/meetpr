import CoreModels

enum ProgressE1RMSegment: CaseIterable, Sendable {
  case total
  case squat
  case bench
  case deadlift

  var family: LiftFamily? {
    switch self {
    case .total: nil
    case .squat: .squat
    case .bench: .bench
    case .deadlift: .deadlift
    }
  }

  var title: String {
    switch self {
    case .total: StudentStrings.localized(.progressTotal)
    case .bench: StudentStrings.localized(.progressBench)
    case .squat, .deadlift: family?.studentDisplayName ?? ""
    }
  }
}

struct ProgressE1RMSelection: Sendable {
  var segment: ProgressE1RMSegment = .total
  private(set) var range: GrowthTimeRange = .thirtyDays
  var showsComparison: Bool { segment == .total }
  var allowsPointSelection: Bool { segment != .total }

  mutating func cycleRange() {
    let ranges = GrowthTimeRange.allCases
    let index = ranges.firstIndex(of: range) ?? 0
    range = ranges[(index + 1) % ranges.count]
  }
}
