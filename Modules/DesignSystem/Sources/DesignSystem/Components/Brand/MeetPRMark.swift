import SwiftUI

/// The black-gold MEETPR wordmark used throughout the refreshed shell.
@MainActor
public struct MeetPRMark: View {
  private let size: CGFloat

  public init(size: CGFloat = 56) {
    self.size = size
  }

  public var body: some View {
    Text("MEETPR")
      .font(.MeetPR.display(size: size * 0.34, weight: .black))
      .tracking(-size * 0.018)
      .foregroundStyle(Color.MeetPR.textPrimary)
      .overlay {
        Text("MEETPR")
          .font(.MeetPR.display(size: size * 0.34, weight: .black))
          .tracking(-size * 0.018)
          .foregroundStyle(
            LinearGradient(
              colors: [Color.MeetPR.gold400, Color.MeetPR.goldCTA],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            )
          )
          .mask(alignment: .trailing) {
            Rectangle()
              .frame(width: size * 0.38)
          }
      }
      .frame(width: size * 2.05, height: size)
      .accessibilityHidden(true)
  }
}

#Preview("MeetPRMark") {
  HStack(spacing: MeetPRSpacing.space6) {
    MeetPRMark(size: 120)
    MeetPRMark(size: 56)
    MeetPRMark(size: 32)
  }
  .padding()
  .background(Color.MeetPR.bgBase)
  .preferredColorScheme(.dark)
}
