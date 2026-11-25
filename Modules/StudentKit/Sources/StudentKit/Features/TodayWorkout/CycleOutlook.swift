import CoreModels
import Foundation

struct CycleOutlookSet: Decodable, Sendable {
  var weightKg: Double?
  var pct: Double?
  var reps: Int
  var minimumReps: Int?
  var rpe: Double?
  var e1rmKg: Double?
  var resolvedPctKg: Double?
  var allowsRPEEstimate = true

  enum CodingKeys: String, CodingKey {
    case weightKg = "kg"
    case pct, reps, rpe, e1rmKg
  }
}

struct CycleOutlookWeek: Decodable, Sendable {
  enum State: String, Decodable, Sendable { case scheduled, unscheduled, notTrained }
  var state: State
  var done = false
  var plan: CycleOutlookSet?
  var actual: CycleOutlookSet?
  var skipped = false
  var dayID: UUID?

  init(
    state: State, done: Bool = false, plan: CycleOutlookSet? = nil,
    actual: CycleOutlookSet? = nil, skipped: Bool = false, dayID: UUID? = nil
  ) {
    self.state = state
    self.done = done
    self.plan = plan
    self.actual = actual
    self.skipped = skipped
    self.dayID = dayID
  }

  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    state = try values.decode(State.self, forKey: .state)
    done = try values.decodeIfPresent(Bool.self, forKey: .done) ?? false
    plan = try values.decodeIfPresent(CycleOutlookSet.self, forKey: .plan)
    skipped = (try? values.decode(String.self, forKey: .actual)) == "skipped"
    actual = skipped ? nil : try values.decodeIfPresent(CycleOutlookSet.self, forKey: .actual)
  }
  private enum CodingKeys: String, CodingKey { case state, done, plan, actual }
}

struct CycleOutlookCell: Identifiable, Sendable {
  let id: Int
  let state: CycleOutlookWeek.State
  let isCurrent: Bool
  var done = false
  var short = false
  var skipped = false
  var main = ""
  var sub = ""
  var shortReps: String?
  var ratio = CycleOutlook.equalRatio
  var isTop = false
  var dayID: UUID?
  var score: Double?
  var hasKg = false
}

/// Spec 114 reference.js coefficients; no training state is mutated by this projection.
enum CycleOutlook {
  static let weightExponent = 2.0
  static let repBonus = 0.03
  static let coachRPEPenalty = 0.03
  static let floorOfTop = 0.85
  static let equalRatio = 0.6
  static let kgIncrement = 2.5
  static let lbIncrement = 5.0
  static let roundingTolerance = 1e-6
  static let scoreTolerance = 1e-9
  static let epleyDivisor = 30.0

  struct Load {
    let weightKg: Double?
    var approximate = false
    var fixed = false
  }

  static func intensity(reps: Int, rpe: Double?) -> Double? {
    guard let rpe, (6...10).contains(rpe) else { return nil }
    return E1RMCalculator.suggestedWeight(e1RM: 1, reps: reps, rpe: rpe)
  }

  static func estimate(_ sets: [CycleOutlookSet]) -> Double? {
    sets.compactMap { set in set.weightKg.map { $0 * (1 + Double(set.reps) / epleyDivisor) } }.max()
  }

  static func load(_ set: CycleOutlookSet, e1RM: Double?, oneRM: Double?) -> Load {
    if let weightKg = set.weightKg { return Load(weightKg: weightKg, fixed: true) }
    if let weightKg = set.e1rmKg { return Load(weightKg: weightKg, approximate: true) }
    if let weightKg = set.resolvedPctKg { return Load(weightKg: weightKg) }
    if let pct = set.pct, let oneRM, oneRM > 0 {
      return Load(weightKg: rounded(oneRM * pct / 100, step: kgIncrement))
    }
    if set.allowsRPEEstimate, let e1RM, e1RM > 0,
      let factor = intensity(reps: set.reps, rpe: set.rpe)
    {
      return Load(weightKg: rounded(e1RM * factor, step: kgIncrement), approximate: true)
    }
    return Load(weightKg: nil)
  }

  static func score(_ set: CycleOutlookSet, load: Load) -> Double? {
    guard
      let intensity = load.weightKg ?? set.pct.map({ $0 / 100 })
        ?? intensity(reps: set.reps, rpe: set.rpe)
    else { return nil }
    let penalty = load.fixed ? coachRPEPenalty * (set.rpe ?? 0) : 0
    let result = pow(intensity, weightExponent) * (1 + repBonus * Double(set.reps) - penalty)
    return result.isFinite ? result : nil
  }

  static func row(
    weeks: [CycleOutlookWeek], e1RM: Double? = nil, oneRM: Double? = nil,
    currentWeekIndex: Int = -1, unit: UnitPreference = .kg, locale: Locale = .current,
    planEstimate: Double? = nil
  ) -> [CycleOutlookCell] {
    let anchor = e1RM ?? planEstimate ?? estimate(weeks.compactMap(\.plan))
    var cells = weeks.enumerated().map { index, week in
      cell(
        week, index: index, current: index == currentWeekIndex,
        e1RM: anchor, oneRM: oneRM, unit: unit, locale: locale)
    }
    let anyKg = cells.contains { $0.score != nil && $0.hasKg }
    let comparable = cells.indices.filter { cells[$0].score != nil && (!anyKg || cells[$0].hasKg) }
    let scores = comparable.compactMap { cells[$0].score }
    guard let high = scores.max(), let minimum = scores.min() else { return cells }
    let low = min(minimum, high * floorOfTop)
    var top: Int?
    for index in comparable {
      guard let score = cells[index].score else { continue }
      cells[index].ratio =
        high - minimum < scoreTolerance ? equalRatio : (score - low) / (high - low)
      if !cells[index].skipped,
        score >= (top.flatMap { cells[$0].score } ?? -.infinity) - scoreTolerance
      {
        top = index
      }
    }
    if let top { cells[top].isTop = true }
    return cells
  }

  // The row projection keeps display inputs explicit at the pure calculation boundary.
  // swiftlint:disable:next function_parameter_count
  private static func cell(
    _ week: CycleOutlookWeek, index: Int, current: Bool,
    e1RM: Double?, oneRM: Double?, unit: UnitPreference, locale: Locale
  ) -> CycleOutlookCell {
    var cell = CycleOutlookCell(id: index, state: week.state, isCurrent: current, dayID: week.dayID)
    guard week.state == .scheduled, let plan = week.plan else {
      cell.main = StudentStrings.localized(
        week.state == .unscheduled ? .cycleUnscheduled : .cycleNotTrained, locale: locale)
      return cell
    }
    cell.done = week.done
    cell.skipped = week.done && week.skipped
    let actual = week.done ? week.actual : nil
    let set = actual ?? plan
    let load =
      actual.map { Load(weightKg: $0.weightKg, fixed: plan.weightKg != nil) }
      ?? load(plan, e1RM: e1RM, oneRM: oneRM)
    cell.score = score(set, load: load)
    cell.hasKg = load.weightKg != nil
    if cell.skipped {
      cell.main = StudentStrings.localized(.cycleSkipped, locale: locale)
    } else if let weightKg = load.weightKg {
      cell.main =
        (load.approximate ? StudentStrings.localized(.cycleApproximate, locale: locale) : "")
        + UnitDisplay.weightText(kg: Decimal(weightKg), unit: unit)
      let minimumReps = plan.minimumReps ?? plan.reps
      cell.short = actual != nil && set.reps < minimumReps
      let reps = cell.short ? "\(set.reps)/\(minimumReps)" : "\(set.reps)"
      cell.shortReps = cell.short ? "\(set.reps)" : nil
      cell.sub = "×\(reps)" + (set.rpe.map { " @\(number($0))" } ?? "")
    } else if let pct = set.pct {
      cell.main = "\(number(pct))%"
      cell.sub = "×\(set.reps)"
    } else {
      cell.main = "\(set.reps) @\(set.rpe.map(number) ?? "—")"
      cell.sub = "RPE"
    }
    return cell
  }

  static func number(_ value: Double) -> String { StudentFormatting.decimal(Decimal(value)) }
  static func rounded(_ value: Double, step: Double) -> Double {
    (value / step + roundingTolerance).rounded(.down) * step
  }
}
