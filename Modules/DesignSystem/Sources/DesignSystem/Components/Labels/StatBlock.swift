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
        .font(Font.MeetPR.monoLabel)
        .tracking(Font.MeetPR.monoLabelTracking)
        .foregroundStyle(Color.MeetPR.brandRed)

      HStack(alignment: .firstTextBaseline, spacing: 6) {
        Text(value)
          .font(Font.MeetPR.displayNumeral)
          .foregroundStyle(Color.MeetPR.fgPrimary)
          .monospacedDigit()

        Text(unit.uppercased())
          .font(Font.MeetPR.displayUnit)
          .tracking(Font.MeetPR.displayUnitTracking)
          .foregroundStyle(Color.MeetPR.brandRed)
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
  .background(Color.MeetPR.bg)
  .preferredColorScheme(.dark)
}

#Preview("StatBlock Light") {
  StatBlock(label: "Squat 1RM", value: "94", unit: "%")
    .padding()
    .background(Color.MeetPR.bg)
    .preferredColorScheme(.light)
}
