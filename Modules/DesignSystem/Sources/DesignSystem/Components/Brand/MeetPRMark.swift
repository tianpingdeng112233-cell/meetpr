import SwiftUI

/// The MeetPR square monogram mark, reproduced 1:1 from `assets/logo/meetpr-mark.svg`
/// (120×120 viewBox: black rounded square · mono "PR" · red underbar).
/// Vector-drawn so it scales crisply at any size without a bundled asset.
@MainActor
public struct MeetPRMark: View {
  private let size: CGFloat

  public init(size: CGFloat = 56) {
    self.size = size
  }

  // Geometry expressed as fractions of the 120-unit source viewBox.
  private func u(_ value: CGFloat) -> CGFloat { size * value / 120 }

  public var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: u(26))
        .fill(Color.black)

      Text("PR")
        .font(.system(size: u(54), weight: .heavy, design: .monospaced))
        .tracking(-u(2))
        .foregroundStyle(Color.white)
        .offset(y: -u(9))

      // Red underbar: source rect x30 y86 w60 h6 → centered, center-y 89.
      RoundedRectangle(cornerRadius: u(1))
        .fill(Color.MeetPR.brandRed)
        .frame(width: u(60), height: u(6))
        .offset(y: u(89 - 60))
    }
    .frame(width: size, height: size)
    .accessibilityHidden(true)
  }
}

#Preview("MeetPRMark") {
  HStack(spacing: 24) {
    MeetPRMark(size: 120)
    MeetPRMark(size: 56)
    MeetPRMark(size: 32)
  }
  .padding()
  .background(Color.MeetPR.bg)
  .preferredColorScheme(.dark)
}
