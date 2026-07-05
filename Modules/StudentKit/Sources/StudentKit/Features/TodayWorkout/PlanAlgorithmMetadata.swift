import CoreModels
import Foundation

struct PlanAlgorithmMetadata: Equatable, Sendable {
  struct Badge: Equatable, Sendable, Identifiable {
    let id: String
    let title: String
    let tone: PlanAlgorithmMetadataBadgeTone
  }

  private static let tmFreshness: TimeInterval = 42 * 24 * 60 * 60

  let blockType: String?
  let mesocyclePhase: String?
  let trainingMax: Decimal?
  let tmSetAt: Date?

  init(
    blockType: String?,
    mesocyclePhase: String?,
    trainingMax: Decimal?,
    tmSetAt: Date?
  ) {
    self.blockType = blockType
    self.mesocyclePhase = mesocyclePhase
    self.trainingMax = trainingMax
    self.tmSetAt = tmSetAt
  }

  init(plan: StudentPlanView) {
    self.init(
      blockType: plan.blockType,
      mesocyclePhase: plan.mesocyclePhase,
      trainingMax: plan.trainingMax,
      tmSetAt: plan.tmSetAt
    )
  }

  var isEmpty: Bool {
    badges(now: Date()).isEmpty
  }

  func badges(now: Date = Date()) -> [Badge] {
    var badges: [Badge] = []
    if let blockTitle {
      badges.append(Badge(id: "block", title: blockTitle, tone: .normal))
    }
    if let phaseTitle {
      badges.append(Badge(id: "phase", title: phaseTitle, tone: .normal))
    }
    if let trainingMax {
      let suffix = isTrainingMaxStale(now: now) ? " · 需复测" : ""
      badges.append(
        Badge(
          id: "trainingMax",
          title: "训练最大值 ≈ 0.9×1RM \(Self.formatKg(trainingMax))kg\(suffix)",
          tone: isTrainingMaxStale(now: now) ? .stale : .normal
        )
      )
    }
    return badges
  }

  private var blockTitle: String? {
    switch blockType {
    case "hypertrophy":
      "增肌块"
    case "strength":
      "力量块"
    case "peaking":
      "巅峰块"
    case "active_rest":
      "恢复块"
    default:
      nil
    }
  }

  private var phaseTitle: String? {
    switch mesocyclePhase {
    case "accumulation":
      "积累"
    case "intensification":
      "强化"
    case "realization":
      "实现"
    case "deload":
      "减载"
    default:
      nil
    }
  }

  private func isTrainingMaxStale(now: Date) -> Bool {
    guard let tmSetAt else { return false }
    return now.timeIntervalSince(tmSetAt) > Self.tmFreshness
  }

  private static func formatKg(_ value: Decimal) -> String {
    let number = NSDecimalNumber(decimal: value)
    return number.doubleValue.formatted(.number.precision(.fractionLength(0...1)))
  }
}

enum PlanAlgorithmMetadataBadgeTone: Equatable, Sendable {
  case normal
  case stale
}
