import SwiftUI

@MainActor
public struct Card<Content: View>: View {
  private let accessibilityLabelText: String
  private let accent: Bool
  private let inset: Bool
  private let content: Content

  public init(
    accessibilityLabel: String = "Card",
    accent: Bool = false,
    inset: Bool = false,
    @ViewBuilder content: () -> Content
  ) {
    self.accessibilityLabelText = accessibilityLabel
    self.accent = accent
    self.inset = inset
    self.content = content()
  }

  public var body: some View {
    content
      .padding(.vertical, inset ? 10 : 14)
      .padding(.horizontal, inset ? 12 : 16)
      .padding(.leading, accent ? 3 : 0)
      .frame(maxWidth: .infinity, alignment: .leading)
      .overlay {
        if accent {
          HStack(spacing: MeetPRSpacing.zero) {
            Rectangle()
              .fill(Color.MeetPR.gold500)
              .frame(width: 3)
            Spacer(minLength: 0)
          }
        }
      }
      .meetPRCardSurface(inset ? .inset : .card)
      .accessibilityElement(children: .contain)
      .accessibilityLabel(accessibilityLabelText)
  }
}

#Preview("Card variants") {
  VStack(spacing: MeetPRSpacing.space3) {
    Card {
      Text("Standard card")
    }
    Card(accent: true) {
      Text("Coach feedback")
    }
    Card(inset: true) {
      Text("Coach note")
    }
  }
  .foregroundStyle(Color.MeetPR.textPrimary)
  .padding()
  .background(Color.MeetPR.bgBase)
  .preferredColorScheme(.dark)
}
