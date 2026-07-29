import SwiftUI

/// A segmented progress bar (mesocycle weeks, cycle progress). Each value is a
/// fill fraction 0...1: `1` = complete (green), `0` = empty (hairline outline),
/// in-between = active gold progress over a dark track.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
public struct ProgressSegments: View {
  private let values: [Double]
  private let spacing: CGFloat
  private let height: CGFloat

  public init(values: [Double], spacing: CGFloat = MeetPRSpacing.sm, height: CGFloat = 4) {
    self.values = values
    self.spacing = spacing
    self.height = height
  }

  public var body: some View {
    HStack(spacing: spacing) {
      ForEach(Array(values.enumerated()), id: \.offset) { _, value in
        Segment(value: value)
      }
    }
    .frame(height: height)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Progress: \(values.filter { $0 >= 1 }.count) of \(values.count) complete")
  }

  private struct Segment: View {
    let value: Double
    var body: some View {
      GeometryReader { geo in
        ZStack(alignment: .leading) {
          if value >= 1 {
            Capsule().fill(Color.MeetPR.success)
          } else if value <= 0 {
            Capsule().stroke(Color.MeetPR.borderSubtle, lineWidth: 1)
          } else {
            Capsule().fill(Color.MeetPR.borderSubtle)
            Capsule()
              .fill(
                LinearGradient(
                  colors: [Color.MeetPR.goldGradientStart, Color.MeetPR.goldGradientEnd],
                  startPoint: .leading,
                  endPoint: .trailing
                )
              )
              .frame(width: geo.size.width * value)
          }
        }
      }
    }
  }
}

#Preview("ProgressSegments") {
  ProgressSegments(values: [1, 1, 0.4, 0])
    .padding()
    .background(Color.MeetPR.bgBase)
    .preferredColorScheme(.dark)
}
