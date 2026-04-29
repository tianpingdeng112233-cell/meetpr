import SwiftUI

@MainActor
public struct Card<Content: View>: View {
  private let accessibilityLabelText: String
  private let content: Content

  public init(
    accessibilityLabel: String = "Card",
    @ViewBuilder content: () -> Content
  ) {
    self.accessibilityLabelText = accessibilityLabel
    self.content = content()
  }

  public var body: some View {
    content
      .padding(MeetPRSpacing.base)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Color.MeetPR.surface1)
      .overlay {
        RoundedRectangle(cornerRadius: MeetPRRadius.lg)
          .stroke(Color.MeetPR.border, lineWidth: 1)
          .allowsHitTesting(false)
      }
      .clipShape(.rect(cornerRadius: MeetPRRadius.lg))
      .accessibilityIdentifier(accessibilityLabelText)
  }
}

#Preview("Card") {
  Card(accessibilityLabel: "Training card") {
    VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
      Eyebrow("SQUAT W3D1")
      Text("Top Set + 3 Backoff")
        .font(Font.MeetPR.headline)
        .foregroundStyle(Color.MeetPR.fgPrimary)
      Text("4 sets - about 28 min")
        .font(Font.MeetPR.footnote)
        .foregroundStyle(Color.MeetPR.fgSecondary)
    }
  }
  .padding()
  .background(Color.MeetPR.bg)
  .preferredColorScheme(.dark)
}

#Preview("Card Light") {
  Card {
    Text("Light mode card")
      .font(Font.MeetPR.body)
      .foregroundStyle(Color.MeetPR.fgPrimary)
  }
  .padding()
  .background(Color.MeetPR.bg)
  .preferredColorScheme(.light)
}
