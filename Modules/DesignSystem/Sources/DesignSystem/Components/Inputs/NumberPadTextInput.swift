import Foundation

/// Unsaved text for an inline numeric cell. The first digit replaces the old value.
public struct NumberPadTextInput: Sendable {
  public private(set) var text: String
  public let field: MeetPRNumberPad.Field
  private var replacesInitialValue = true

  public init(value: String, field: MeetPRNumberPad.Field) {
    self.text = value.replacing(",", with: ".")
    self.field = field
  }

  /// A trailing decimal is an editing state, not part of the stored numeric string.
  public var committedText: String {
    text.hasSuffix(".") ? String(text.dropLast()) : text
  }

  public var isValid: Bool {
    if text.isEmpty { return true }
    guard let value = Double(text), value.isFinite else { return false }
    switch field {
    case .weight: return value >= 0
    case .reps: return (1...99).contains(value) && value.rounded() == value
    case .rpe: return (5...10).contains(value) && (value * 2).rounded() == value * 2
    case .rir: return (0...9).contains(value) && value.rounded() == value
    }
  }

  public mutating func deleteLast() {
    replacesInitialValue = false
    if !text.isEmpty { text.removeLast() }
  }

  public mutating func append(_ character: String) {
    guard character.count == 1, "0123456789.".contains(character) else { return }
    guard character != "." || (field != .reps && field != .rir) else { return }
    let base = replacesInitialValue ? "" : text
    let candidate = character == "." && base.isEmpty ? "0." : base + character
    guard candidate.count <= 9, candidate.filter({ $0 == "." }).count <= 1,
      candidate.split(separator: ".", omittingEmptySubsequences: false).last.map({
        !candidate.contains(".") || $0.count <= 1
      }) == true
    else { return }
    text = candidate
    replacesInitialValue = false
  }
}
