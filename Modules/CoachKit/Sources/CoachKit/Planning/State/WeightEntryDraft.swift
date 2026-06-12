import Foundation

/// Expression state for the panel — a small four-function calculator
/// (David 2026-06-12: 要有加减乘除,不绑死 % 换算), kept off the view so
/// the editing/precedence rules test in isolation. `×`/`÷` bind before
/// `+`/`−`; the live result re-evaluates as tokens land.
struct WeightEntryDraft: Equatable {
  enum Operation: String, CaseIterable {
    case add = "+"
    case subtract = "−"
    case multiply = "×"
    case divide = "÷"
  }

  /// operands.count == operators.count + 1; the last operand may still be
  /// in-progress (empty while awaiting digits after an operator).
  private(set) var operands: [String]
  private(set) var operators: [Operation]

  init(initialValue: Decimal) {
    operands = [initialValue > 0 ? initialValue.planningFormatted() : ""]
    operators = []
  }

  // MARK: - Display

  /// The big number: the live result of everything typed so far.
  var displayText: String {
    if operators.isEmpty {
      return operands[0].isEmpty ? "0" : operands[0]
    }
    guard let result = evaluated() else { return "—" }
    return result.planningFormatted()
  }

  /// The small "185 × 0.85" line; empty until an operator lands.
  var expressionText: String {
    guard !operators.isEmpty else { return "" }
    var parts: [String] = [operands[0].isEmpty ? "0" : operands[0]]
    for (index, operation) in operators.enumerated() {
      parts.append(operation.rawValue)
      let operand = operands[index + 1]
      if !operand.isEmpty { parts.append(operand) }
    }
    return parts.joined(separator: " ")
  }

  /// Commit value: the evaluated expression (÷0 falls back to 0).
  var value: Decimal { evaluated() ?? 0 }

  // MARK: - Keys

  mutating func tapDigit(_ digit: Int) {
    guard (0...9).contains(digit) else { return }
    var current = operands[operands.count - 1]
    // Two decimal places max: operands are calculator inputs (×0.85 must
    // be typable, Codex review) — the 0.5/2.5 grid rounding happens at the
    // integration boundary on commit, not here.
    if let dotIndex = current.firstIndex(of: "."),
      current.distance(from: dotIndex, to: current.endIndex) > 2
    {
      return
    }
    if current == "0" { current = "" }
    guard current.count < 7 else { return }
    current.append(String(digit))
    operands[operands.count - 1] = current
  }

  mutating func tapDot() {
    var current = operands[operands.count - 1]
    guard !current.contains(".") else { return }
    current = current.isEmpty ? "0." : current + "."
    operands[operands.count - 1] = current
  }

  mutating func tapBackspace() {
    var current = operands[operands.count - 1]
    if current.isEmpty {
      guard !operators.isEmpty else { return }
      operators.removeLast()
      operands.removeLast()
      return
    }
    current.removeLast()
    operands[operands.count - 1] = current
  }

  mutating func tapOperation(_ operation: Operation) {
    if operands[operands.count - 1].isEmpty {
      // Repeated operator taps re-pick the operator; a leading operator
      // applies to the (implicit zero / previous result) first operand.
      if operators.isEmpty { return }
      operators[operators.count - 1] = operation
      return
    }
    operators.append(operation)
    operands.append("")
  }

  /// Replace the in-progress operand with a reference value (1RM / 主项).
  mutating func insert(amount: Decimal) {
    guard amount > 0 else { return }
    operands[operands.count - 1] = amount.planningFormatted()
  }

  /// Steppers act on the live result, collapsing the expression first.
  mutating func step(by delta: Decimal) {
    let next = max(0, value + delta)
    collapse(to: next.roundedToPlanningIncrement(PlanningDecimalStep.half))
  }

  /// % quick keys land on the plate-realistic 2.5 grid.
  mutating func apply(percent: Int, of base: Decimal) {
    guard base > 0, percent > 0 else { return }
    let raw = base * Decimal(percent) / 100
    collapse(to: raw.roundedToPlanningIncrement(PlanningDecimalStep.plate))
  }

  private mutating func collapse(to result: Decimal) {
    operands = [result.planningFormatted()]
    operators = []
  }

  // MARK: - Evaluation (× ÷ before + −)

  private func evaluated() -> Decimal? {
    let posix = Locale(identifier: "en_US_POSIX")
    var numbers: [Decimal] = []
    var pendingOps: [Operation] = []
    for (index, raw) in operands.enumerated() {
      guard !raw.isEmpty, let number = Decimal(string: raw, locale: posix) else {
        continue
      }
      numbers.append(number)
      if index < operators.count { pendingOps.append(operators[index]) }
    }
    // Drop a trailing operator awaiting its operand.
    while pendingOps.count >= numbers.count, !pendingOps.isEmpty {
      pendingOps.removeLast()
    }
    guard !numbers.isEmpty else { return nil }
    guard let (sums, sumOps) = Self.reduceMultiplicative(numbers, pendingOps) else {
      return nil
    }
    var result = sums[0]
    for (index, operation) in sumOps.enumerated() {
      result = operation == .add ? result + sums[index + 1] : result - sums[index + 1]
    }
    return result
  }

  /// Pass 1 of the precedence evaluation: collapse ×/÷ runs, leaving only
  /// +/− terms. nil on division by zero.
  private static func reduceMultiplicative(
    _ numbers: [Decimal],
    _ operations: [Operation]
  ) -> (terms: [Decimal], operations: [Operation])? {
    var terms: [Decimal] = [numbers[0]]
    var additive: [Operation] = []
    for (index, operation) in operations.enumerated() {
      let rhs = numbers[index + 1]
      switch operation {
      case .multiply:
        terms[terms.count - 1] *= rhs
      case .divide:
        guard rhs != 0 else { return nil }
        terms[terms.count - 1] /= rhs
      case .add, .subtract:
        additive.append(operation)
        terms.append(rhs)
      }
    }
    return (terms, additive)
  }
}
