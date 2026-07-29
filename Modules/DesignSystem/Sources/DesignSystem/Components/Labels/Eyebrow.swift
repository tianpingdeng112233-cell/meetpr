import SwiftUI

@MainActor
public struct Eyebrow: View {
  private let title: String
  private let color: Color
  private let showsRule: Bool

  public init(
    _ title: String,
    color: Color = Color.MeetPR.gold500,
    showsRule: Bool = true
  ) {
    self.title = title
    self.color = color
    self.showsRule = showsRule
  }

  public var body: some View {
    HStack(spacing: MeetPRSpacing.sm) {
      Text(title.uppercased())
        .font(.MeetPR.mono(size: 11, weight: .bold))
        .tracking(0.8)
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
    Eyebrow("AI_SUGGESTION //", color: Color.MeetPR.textMuted)
  }
  .padding()
  .background(Color.MeetPR.bgBase)
  .preferredColorScheme(.dark)
}

#Preview("Eyebrow Light") {
  Eyebrow("SQUAT STANDARD")
    .padding()
    .background(Color.MeetPR.bgBase)
    .preferredColorScheme(.light)
}
