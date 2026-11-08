import DesignSystem

struct SetEntryNumberPadEdit {
  let field: MeetPRNumberPad.Field
  let original: String
  let minimumWeight: Double
  private var text: String?

  init(field: MeetPRNumberPad.Field, original: String, minimumWeight: Double) {
    self.field = field
    self.original = original
    self.minimumWeight = minimumWeight
  }

  var displayText: String { text ?? original }
  @MainActor var valueToSave: Double? {
    guard let text, !text.isEmpty, let value = Double(text), value.isFinite, value >= 0 else {
      return nil
    }
    if field == .reps && (!(1...100).contains(value) || value.rounded() != value) { return nil }
    return MeetPRNumberPad.snapped(value, field: field, minimumWeight: minimumWeight)
  }
  mutating func update(_ text: String) { self.text = text }
}
