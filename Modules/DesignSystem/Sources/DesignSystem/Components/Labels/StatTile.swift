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
    .accessibilityLabel("\(label)，\(value) \(unit)\(delta.isEmpty ? "" : "，变化 \(delta)")")
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
    StatTile(label: "体重", value: "83", unit: "kg", delta: "-0.4")
    StatTile(label: "距比赛", value: "3", unit: "天", accent: .gold)
    StatTile(label: "连胜", value: "12", unit: "次", delta: "+2", accent: .success)
    StatTile(label: "漏练", value: "1", unit: "次", accent: .danger)
  }
  .padding()
  .background(Color.MeetPR.bgInset)
  .preferredColorScheme(.dark)
}

#Preview("StatTile · All Accents · Light") {
  LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: MeetPRSpacing.point10) {
    StatTile(label: "体重", value: "83", unit: "kg", delta: "-0.4")
    StatTile(label: "距比赛", value: "3", unit: "天", accent: .gold)
    StatTile(label: "连胜", value: "12", unit: "次", delta: "+2", accent: .success)
    StatTile(label: "漏练", value: "1", unit: "次", accent: .danger)
  }
  .padding()
  .background(Color.MeetPR.bgBase)
  .preferredColorScheme(.light)
}
