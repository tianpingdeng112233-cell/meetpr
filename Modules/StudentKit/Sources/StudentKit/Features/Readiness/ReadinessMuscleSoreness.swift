enum ReadinessMuscleSoreness: Int, CaseIterable, Sendable {
  case mild = 1
  case moderate = 2
  case noticeable = 3
  case severe = 4

  static let noneLabel = "完全无酸痛"

  var label: String {
    switch self {
    case .mild: "轻微"
    case .moderate: "中等"
    case .noticeable: "明显酸痛"
    case .severe: "严重酸痛"
    }
  }

  static func label(for severity: Int?) -> String {
    guard let severity, let soreness = Self(rawValue: severity) else { return noneLabel }
    return soreness.label
  }

  static func nextSeverity(after severity: Int?) -> Int? {
    guard let severity else { return mild.rawValue }
    return severity < severe.rawValue ? severity + 1 : nil
  }
}
