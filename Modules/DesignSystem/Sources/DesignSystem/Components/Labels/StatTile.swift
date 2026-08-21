import SwiftUI

/// Compact numeric card defined by `StatTile.dc.html`.
@MainActor
public struct StatTile: View {
  public enum Accent: Sendable {
    case neutral
    case gold
    case success
    case danger
  }

  let label: String
  let value: String
  let unit: String
  let delta: String
  let accent: Accent

  public init(
    label: String,
    value: String,
    unit: String = "kg",
    delta: String = "",
    accent: Accent = .neutral
  ) {
    self.label = label
    self.value = value
    self.unit = unit
    self.delta = delta
    self.accent = accent
  }

  public init(
    label: String,
    value: Int,
    unit: String = "kg",
    delta: String = "",
    accent: Accent = .neutral
  ) {
    self.init(
      label: label,
      value: value.formatted(),
      unit: unit,
      delta: delta,
      accent: accent
    )
  }

  public init(
    label: String,
    value: Double,
    unit: String = "kg",
    delta: String = "",
    accent: Accent = .neutral
  ) {
    self.init(
      label: label,
      value: value.formatted(.number.precision(.fractionLength(0...2))),
      unit: unit,
      delta: delta,
      accent: accent
    )
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.point6) {
      Text(label)
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size11))
        .tracking(0.66)
        .foregroundStyle(Color.MeetPR.textMuted)

      HStack(alignment: .lastTextBaseline, spacing: MeetPRSpacing.point5) {
        Text(value)
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size28, weight: .bold))
          .foregroundStyle(valueColor)
          .monospacedDigit()

        Text(unit)
          .font(.MeetPR.body(size: MeetPRFontMetrics.size12, weight: .medium))
          .foregroundStyle(Color.MeetPR.textMuted)
      }

      if !delta.isEmpty {
        Text(delta)
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size12, weight: .bold))
          .foregroundStyle(deltaColor)
      }
    }
    .padding(.horizontal, MeetPRSpacing.space4)
    .padding(.vertical, MeetPRSpacing.point14)
    .background(Color.MeetPR.surfaceCard)
    .clipShape(.rect(cornerRadius: MeetPRRadius.card))
    .shadow(color: Color.MeetPR.cardShadow, radius: 9, y: 4)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(
      DesignSystemStrings.statAccessibilityLabel(
        label: label,
        value: value,
        unit: unit,
        delta: delta.isEmpty ? "" : DesignSystemStrings.statChange(delta)
      )
    )
  }

  private var valueColor: Color {
    switch accent {
    case .neutral: Color.MeetPR.textPrimary
    case .gold: Color.MeetPR.gold500
    case .success: Color.MeetPR.success
    case .danger: Color.MeetPR.danger
    }
  }

  private var deltaColor: Color {
    if delta.hasPrefix("-") {
      return Color.MeetPR.danger
    }
    if delta.hasPrefix("+") {
      return Color.MeetPR.success
    }
    return Color.MeetPR.textMuted
  }
}

#Preview("StatTile · All Accents · Dark") {
  LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: MeetPRSpacing.point10) {
    StatTile(label: DesignSystemStrings.bodyWeight, value: "83", unit: "kg", delta: "-0.4")
    StatTile(
      label: DesignSystemStrings.daysUntilMeet, value: "3", unit: DesignSystemStrings.daysUnit,
      accent: .gold)
    StatTile(
      label: DesignSystemStrings.streak, value: "12", unit: DesignSystemStrings.timesUnit,
      delta: "+2", accent: .success)
    StatTile(
      label: DesignSystemStrings.missedWorkout, value: "1", unit: DesignSystemStrings.timesUnit,
      accent: .danger)
  }
  .padding()
  .background(Color.MeetPR.bgInset)
  .preferredColorScheme(.dark)
}

#Preview("StatTile · All Accents · Light") {
  LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: MeetPRSpacing.point10) {
    StatTile(label: DesignSystemStrings.bodyWeight, value: "83", unit: "kg", delta: "-0.4")
    StatTile(
      label: DesignSystemStrings.daysUntilMeet, value: "3", unit: DesignSystemStrings.daysUnit,
      accent: .gold)
    StatTile(
      label: DesignSystemStrings.streak, value: "12", unit: DesignSystemStrings.timesUnit,
      delta: "+2", accent: .success)
    StatTile(
      label: DesignSystemStrings.missedWorkout, value: "1", unit: DesignSystemStrings.timesUnit,
      accent: .danger)
  }
  .padding()
  .background(Color.MeetPR.bgBase)
  .preferredColorScheme(.light)
}
