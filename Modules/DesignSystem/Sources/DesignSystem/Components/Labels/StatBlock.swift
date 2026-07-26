import SwiftUI

@MainActor
public struct StatBlock: View {
  private let label: String
  private let value: String
  private let unit: String

  public init(label: String, value: String, unit: String) {
    self.label = label
    self.value = value
    self.unit = unit
  }

  public var body: some View {
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

#Preview("StatBlock") {
  HStack(alignment: .bottom, spacing: MeetPRSpacing.lg) {
    StatBlock(label: "Squat Standard", value: "320", unit: "KG")
    StatBlock(label: "Bench", value: "200", unit: "KG")
  }
  .padding()
  .background(Color.MeetPR.bgBase)
  .preferredColorScheme(.dark)
}

#Preview("StatBlock Light") {
  StatBlock(label: "Squat 1RM", value: "94", unit: "%")
    .padding()
    .background(Color.MeetPR.bgBase)
    .preferredColorScheme(.light)
}
