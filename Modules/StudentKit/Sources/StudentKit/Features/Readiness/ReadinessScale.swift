enum ReadinessScale: CaseIterable, Sendable {
  case sleepQuality
  case energy
  case stress
  case mood

  var title: String {
    switch self {
    case .sleepQuality: "昨晚睡得怎么样？"
    case .energy: "今天精力如何？"
    case .stress: "今天压力大吗？"
    case .mood: "今天情绪如何？"
    }
  }

  /// Copy is ordered by its stored score: index 0 is score 1 and index 4 is
  /// score 5. All scales therefore keep 5 as the positive end.
  var labels: [String] {
    switch self {
    case .sleepQuality:
      ["很差/几乎没睡", "较差", "一般", "较好", "睡得很好"]
    case .energy:
      ["精疲力竭", "疲惫", "一般", "较有精力", "精力充沛"]
    case .stress:
      ["压力很大", "有压力", "一般", "较放松", "很放松"]
    case .mood:
      ["很差", "低落", "一般", "好", "很好"]
    }
  }

  func label(for score: Int) -> String? {
    guard (1...5).contains(score) else { return nil }
    return labels[score - 1]
  }
}
