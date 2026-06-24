import SwiftUI

/// The MeetPR square brand mark — concept "02 · Stacked Lockup" from the logo
/// exploration: black squircle · tiny mono "MEET" eyebrow · heavy "PR" · a single
/// red signal block. Vector-drawn so it scales crisply at any size without a
/// bundled asset, and matches the app icon 1:1.
@MainActor
public struct MeetPRMark: View {
  private let size: CGFloat

  public init(size: CGFloat = 56) {
    self.size = size
  }

  /// Geometry as fractions of the mark's edge length (same ratios as the design source).
  private func f(_ value: CGFloat) -> CGFloat { size * value }

  // Fixed identity colors: the mark is always the dark tile, regardless of color scheme.
  private let meetGrey = Color(red: 181 / 255, green: 181 / 255, blue: 181 / 255)  // #B5B5B5

  public var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: f(0.2237), style: .continuous)
        .fill(Color.black)

      // The lockup, rigidly shifted up so "PR" sits at the tile's true center.
      ZStack {
        VStack(spacing: f(0.04)) {
          Text("MEET")
            .font(.system(size: f(0.075), weight: .semibold, design: .monospaced))
            .tracking(f(0.32 * 0.075))  // 0.32em of the eyebrow size
            .padding(.leading, f(0.32 * 0.075))  // offset trailing tracking → stays centered
            .foregroundStyle(meetGrey)

          Text("PR")
            .font(.system(size: f(0.52), weight: .black))
            .tracking(-f(0.055 * 0.52))  // -0.055em, tight display tracking
            .foregroundStyle(Color.white)
        }

        // Single red signal rule (#E5221E) — ≈ MEET width — frames "PR" from below.
        Rectangle()
          .fill(Color.MeetPR.brandRed)
          .frame(width: f(0.30), height: f(0.03))
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
          .padding(.bottom, f(0.13))
      }
      .offset(y: -f(0.065))
    }
    .frame(width: size, height: size)
    .clipShape(RoundedRectangle(cornerRadius: f(0.2237), style: .continuous))
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
