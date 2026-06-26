import CoreModels
import Foundation

// Turns one exercise's grid cells (组*次 / 强度 / 浮动列) into a list of
// `ParsedSet`, following the spec 043 解析规则附录 verbatim. Iron rule: copy
// numbers exactly, never compute a weight from a percentage; anything the parser
// can't structure is left empty with the original text preserved as `coachNote`
// for the coach to resolve in review.

struct SetCountReps: Equatable, Sendable {
  let count: Int
  let reps: Int?
  let repsMax: Int?
  /// `N组` form (e.g. `4组 力竭`): an open-ended AMRAP block, reps filled in review.
  let openEnded: Bool
}

enum SetLineParser {
  /// 组*次 (col2). Forms: `4*8`, `4*8-12` (range), `4组` (open-ended).
  static func parseSetsReps(_ raw: String) -> SetCountReps? {
    let text = normalize(raw)
    guard !text.isEmpty else { return nil }

    // `N组` — open-ended set count, reps deferred to review.
    if let range = text.range(of: #"^(\d+)\s*组$"#, options: .regularExpression) {
      let count = Int(text[range].prefix { $0.isNumber }) ?? 0
      guard count > 0 else { return nil }
      return SetCountReps(count: count, reps: nil, repsMax: nil, openEnded: true)
    }

    // `N*a` or `N*a-b`. Accept ×/x/* as the separator.
    let parts = text.replacing("×", with: "*").replacing("x", with: "*")
      .replacing("X", with: "*").split(separator: "*", omittingEmptySubsequences: true)
    guard parts.count == 2, let count = Int(parts[0]), count > 0 else { return nil }

    let repsPart = parts[1]
    if repsPart.contains("-") {
      let bounds = repsPart.split(separator: "-")
      guard bounds.count == 2, let low = Int(bounds[0]), let high = Int(bounds[1]) else {
        return nil
      }
      return SetCountReps(count: count, reps: low, repsMax: high, openEnded: false)
    }
    guard let reps = Int(repsPart) else { return nil }
    return SetCountReps(count: count, reps: reps, repsMax: nil, openEnded: false)
  }

  /// Full expansion of one exercise line into its sets.
  static func expand(
    setsCell: String,
    intensityCell: String,
    float1: String? = nil,
    float2: String? = nil,
    exerciseName: String = ""
  ) -> [ParsedSet] {
    guard let setsReps = parseSetsReps(setsCell) else { return [] }

    var sets = (0..<setsReps.count).map { _ in
      ParsedSet(
        reps: setsReps.reps,
        repsMax: setsReps.repsMax,
        setType: setsReps.openEnded ? .amrap : .working
      )
    }

    applyIntensity(&sets, raw: intensityCell, exerciseName: exerciseName)
    applyFloat(
      &sets, raw: firstNonEmpty(float1, float2), exerciseName: exerciseName,
      intensityCell: intensityCell)
    return sets
  }

  // MARK: - 强度 (col3)

  // swiftlint:disable:next cyclomatic_complexity
  private static func applyIntensity(_ sets: inout [ParsedSet], raw: String, exerciseName: String) {
    let original = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !original.isEmpty else { return }
    let text = normalize(raw)

    // D{d}/L{l} 递增{s}  (L optional) — per-set ladder.
    if let ladder = parseLadder(text) {
      for index in sets.indices {
        var weight = ladder.start + Decimal(index) * ladder.step
        if let cap = ladder.cap, weight > cap { weight = cap }
        sets[index].weightKg = weight
        sets[index].setType = sets[index].setType == .amrap ? .amrap : .working
      }
      return
    }

    // Pure number list `120/125/130/135` — per-set weights.
    if text.range(of: #"^[\d.]+(/[\d.]+)+$"#, options: .regularExpression) != nil {
      let weights = text.split(separator: "/").compactMap { Decimal(string: String($0)) }
      guard !weights.isEmpty else { return }
      for index in sets.indices {
        sets[index].weightKg = weights[min(index, weights.count - 1)]
      }
      return
    }

    // Single number — all sets same weight.
    if let single = Decimal(string: text),
      text.range(of: #"^[\d.]+$"#, options: .regularExpression) != nil
    {
      for index in sets.indices { sets[index].weightKg = single }
      return
    }

    // rpe{n} — all sets share one RPE.
    if let rpeRange = text.range(of: #"^rpe\s*[\d.]+$"#, options: .regularExpression) {
      let digits = text[rpeRange].drop { !$0.isNumber }
      if let rpe = Decimal(string: String(digits)) {
        for index in sets.indices { sets[index].rpe = rpe }
      }
      return
    }

    // Bare `rpe` — per-set RPE comes from the float column (handled there).
    if text == "rpe" { return }

    // amrap / 力竭 — AMRAP, reps filled in review, original kept as cue.
    if text.contains("力竭") || text.contains("amrap") {
      for index in sets.indices {
        sets[index].setType = .amrap
        sets[index].coachNote = original
      }
      return
    }

    // 减{x}kg*{k} / 回组减{x} — back-off, weight filled in review.
    if text.contains("减") {
      for index in sets.indices {
        sets[index].setType = .backoff
        sets[index].coachNote = original
      }
      return
    }

    // {n}%top / D/L without 递增 / anything else — leave weight empty, keep cue.
    for index in sets.indices { sets[index].coachNote = original }
  }

  private struct Ladder {
    let start: Decimal
    let cap: Decimal?
    let step: Decimal
  }

  private static func parseLadder(_ text: String) -> Ladder? {
    // D80/L90 递增5kg  ·  D62.5/L70 增2.5kg  ·  D100 递增5 (L optional)
    let pattern = #"^d([\d.]+)(?:/l([\d.]+))?\s*(?:递增|增)([\d.]+)(?:kg)?$"#
    guard
      let match = text.range(of: pattern, options: .regularExpression)
    else { return nil }
    let matched = String(text[match])
    let scanner = matched
    // Extract the three numbers in order.
    let numbers = numericTokens(in: scanner)
    guard numbers.count >= 2 else { return nil }
    if numbers.count == 2 {
      // D + step, no cap.
      return Ladder(start: numbers[0], cap: nil, step: numbers[1])
    }
    return Ladder(start: numbers[0], cap: numbers[1], step: numbers[2])
  }

  // MARK: - 浮动列 (col4/col5)

  private static func applyFloat(
    _ sets: inout [ParsedSet],
    raw: String,
    exerciseName: String,
    intensityCell: String
  ) {
    let original = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !original.isEmpty else { return }
    let text = normalize(raw)
    let count = sets.count

    // Integer whose digit count == set count and every digit 5–9 → per-set RPE.
    if text.range(of: #"^\d+$"#, options: .regularExpression) != nil,
      text.count == count,
      text.allSatisfy({ ("5"..."9").contains($0) })
    {
      for (index, digit) in text.enumerated() where index < count {
        sets[index].rpe = Decimal(string: String(digit))
      }
      return
    }

    // Integer on a tempo exercise → tempo cue 「节奏 a-b-c」.
    if text.range(of: #"^\d+$"#, options: .regularExpression) != nil,
      isTempoContext(exerciseName: exerciseName, intensityCell: intensityCell)
    {
      let note = tempoNote(fromDigits: text)
      for index in sets.indices where sets[index].coachNote == nil { sets[index].coachNote = note }
      return
    }

    // rpe{n} in the float column.
    if let rpeRange = text.range(of: #"^rpe\s*[\d.]+$"#, options: .regularExpression) {
      let digits = text[rpeRange].drop { !$0.isNumber }
      if let rpe = Decimal(string: String(digits)) {
        for index in sets.indices { sets[index].rpe = rpe }
      }
      return
    }

    // Any other content → keep verbatim as a cue (don't clobber an existing one).
    for index in sets.indices where sets[index].coachNote == nil {
      sets[index].coachNote = original
    }
  }

  // MARK: - tempo helpers

  static func isTempoContext(exerciseName: String, intensityCell: String) -> Bool {
    let name = exerciseName
    if name.contains("节奏") || name.contains("离心") || name.contains("暂停") { return true }
    return normalize(intensityCell).contains("%top")
  }

  /// `310` → 「节奏3-1-0」 (each digit dashed).
  static func tempoNote(fromDigits digits: String) -> String {
    "节奏" + digits.map(String.init).joined(separator: "-")
  }

  /// Splits a name like `节奏深蹲310` into (`节奏深蹲`, tempo cue) when the
  /// remaining name is a tempo movement; otherwise returns the name unchanged.
  static func stripTempoSuffix(_ name: String) -> (name: String, tempoNote: String?) {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    guard let range = trimmed.range(of: #"\d+$"#, options: .regularExpression) else {
      return (trimmed, nil)
    }
    let base = String(trimmed[trimmed.startIndex..<range.lowerBound])
    let digits = String(trimmed[range])
    guard isTempoContext(exerciseName: base, intensityCell: "") else {
      return (trimmed, nil)
    }
    return (base, tempoNote(fromDigits: digits))
  }

  // MARK: - utilities

  private static func normalize(_ raw: String) -> String {
    raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
  }

  private static func firstNonEmpty(_ values: String?...) -> String {
    for value in values {
      if let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return value }
    }
    return ""
  }

  private static func numericTokens(in text: String) -> [Decimal] {
    var tokens: [Decimal] = []
    var current = ""
    for character in text {
      if character.isNumber || character == "." {
        current.append(character)
      } else if !current.isEmpty {
        if let value = Decimal(string: current) { tokens.append(value) }
        current = ""
      }
    }
    if !current.isEmpty, let value = Decimal(string: current) { tokens.append(value) }
    return tokens
  }
}
