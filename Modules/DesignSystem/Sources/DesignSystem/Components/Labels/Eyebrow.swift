import SwiftUI

@MainActor
public struct Eyebrow: View {
  private let title: String
  private let color: Color
  private let showsRule: Bool

  public init(
    _ title: String,
    color: Color = Color.MeetPR.brandRed,
    showsRule: Bool = true
  ) {
    self.title = title
    self.color = color
    self.showsRule = showsRule
  }

  public var body: some View {
    HStack(spacing: MeetPRSpacing.sm) {
      Text(title.uppercased())
        .font(Font.MeetPR.monoLabel)
        .tracking(Font.MeetPR.monoLabelTracking)
        .foregroundStyle(color)

      if showsRule {
        Rectangle()
          .fill(color)
          .frame(width: 32, height: 1)
      }
    }
    .fixedSize(horizontal: true, vertical: false)
    .accessibilityLabel(title)
    .accessibilityHint("Technical section label.")
  }
}

#Preview("Eyebrow") {
  VStack(alignment: .leading, spacing: MeetPRSpacing.base) {
    Eyebrow("PROTOCOL 01")
    Eyebrow("AI_SUGGESTION //", color: Color.MeetPR.fgTertiary)
  }
  .padding()
  .background(Color.MeetPR.bg)
  .preferredColorScheme(.dark)
}

#Preview("Eyebrow Light") {
  Eyebrow("SQUAT STANDARD")
    .padding()
    .background(Color.MeetPR.bg)
    .preferredColorScheme(.light)
}
