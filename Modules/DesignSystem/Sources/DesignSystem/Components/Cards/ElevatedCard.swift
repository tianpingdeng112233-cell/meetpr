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
      .background(Color.MeetPR.surface2)
      .overlay {
        RoundedRectangle(cornerRadius: MeetPRRadius.lg)
          .stroke(Color.MeetPR.border, lineWidth: 1)
      }
      .clipShape(.rect(cornerRadius: MeetPRRadius.lg))
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
        .foregroundStyle(Color.MeetPR.fgPrimary)
      Text("Reduce W4 backoff by 5%?")
        .font(Font.MeetPR.footnote)
        .foregroundStyle(Color.MeetPR.fgSecondary)
    }
  }
  .padding()
  .background(Color.MeetPR.bg)
  .preferredColorScheme(.dark)
}

#Preview("ElevatedCard Light") {
  ElevatedCard {
    Text("Light mode elevated card")
      .font(Font.MeetPR.body)
      .foregroundStyle(Color.MeetPR.fgPrimary)
  }
  .padding()
  .background(Color.MeetPR.bg)
  .preferredColorScheme(.light)
}
