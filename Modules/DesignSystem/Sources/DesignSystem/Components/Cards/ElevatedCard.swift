import SwiftUI

@MainActor
public struct ElevatedCard<Content: View>: View {
  private let accessibilityLabelText: String
  private let content: Content

  public init(
    accessibilityLabel: String = "Elevated card",
    @ViewBuilder content: () -> Content
  ) {
    self.accessibilityLabelText = accessibilityLabel
    self.content = content()
  }

  public var body: some View {
    content
      .padding(MeetPRSpacing.base)
      .frame(maxWidth: .infinity, alignment: .leading)
      .meetPRCardSurface(.card, fill: Color.MeetPR.surfaceElevated)
      .accessibilityElement(children: .contain)
      .accessibilityLabel(accessibilityLabelText)
  }
}

#Preview("ElevatedCard") {
  ElevatedCard(accessibilityLabel: "Suggestion card") {
    VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
      Eyebrow("SYSTEM //")
      Text("Detected RPE 10 across 3 sessions.")
        .font(Font.MeetPR.bodyEmphasis)
        .foregroundStyle(Color.MeetPR.textPrimary)
      Text("Reduce W4 backoff by 5%?")
        .font(Font.MeetPR.footnote)
        .foregroundStyle(Color.MeetPR.textSecondary)
    }
  }
  .padding()
  .background(Color.MeetPR.bgBase)
  .preferredColorScheme(.dark)
}

#Preview("ElevatedCard Light") {
  ElevatedCard {
    Text("Light mode elevated card")
      .font(Font.MeetPR.body)
      .foregroundStyle(Color.MeetPR.textPrimary)
  }
  .padding()
  .background(Color.MeetPR.bgBase)
  .preferredColorScheme(.light)
}
