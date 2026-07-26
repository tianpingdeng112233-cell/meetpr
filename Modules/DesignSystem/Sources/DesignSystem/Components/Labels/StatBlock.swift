import SwiftUI

/// ⛔️ FROZEN W0 view — compatibility quarantine, not a v3 component.
///
/// New code must use `StatTile`. This implementation preserves the exact
/// `2e46d52` rendering until the coach migration wave, then should be deleted.
@MainActor
struct LegacyStatBlock: View {
  let label: String
  let value: String
  let unit: String

  init(label: String, value: String, unit: String) {
    self.label = label
    self.value = value
    self.unit = unit
  }

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.xs) {
      Text(label.uppercased())
        .font(.MeetPR.mono(size: 11, weight: .bold))
        .tracking(0.8)
        .foregroundStyle(Color.MeetPR.textMuted)

      HStack(alignment: .firstTextBaseline, spacing: MeetPRSpacing.point6) {
        Text(value)
          .font(.MeetPR.display(size: 54, weight: .black))
          .foregroundStyle(Color.MeetPR.textPrimary)
          .monospacedDigit()

        Text(unit.uppercased())
          .font(.MeetPR.mono(size: 12, weight: .bold))
          .tracking(Font.MeetPR.displayUnitTracking)
          .foregroundStyle(Color.MeetPR.gold500)
      }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("\(label) \(value) \(unit)")
    .accessibilityHint("Displays a key numeric training stat.")
  }
}

/// Frozen W0 public entry. New code must use `StatTile`.
@MainActor
public struct StatBlock: View {
  private let legacy: LegacyStatBlock

  public init(label: String, value: String, unit: String) {
    legacy = LegacyStatBlock(label: label, value: value, unit: unit)
  }

  public var body: some View {
    legacy
  }
}
