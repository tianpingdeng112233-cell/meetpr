import SwiftUI

/// The black-gold MEETPR wordmark used throughout the refreshed shell.
@MainActor
public struct MeetPRMark: View {
  private let size: CGFloat

  public init(size: CGFloat = 56) {
    self.size = size
  }

  /// The mockup draws the wordmark as a 5px `text-primary` stroke with a
  /// `bg-base` knockout fill (`-webkit-text-stroke` + overlay). SwiftUI has no
  /// text stroke, so the stroke mass is eight offset copies under the fill.
  public var body: some View {
    let fontSize = size * 0.34
    let strokeRadius = fontSize * 0.16
    ZStack {
      ForEach(0..<8, id: \.self) { index in
        let angle = Double(index) * .pi / 4
        markText
          .foregroundStyle(Color.MeetPR.textPrimary)
          .offset(x: cos(angle) * strokeRadius, y: sin(angle) * strokeRadius)
      }
      markText
        .foregroundStyle(Color.MeetPR.bgBase)
    }
    .frame(width: size * 2.05, height: size)
    .accessibilityHidden(true)
  }

  /// `letter-spacing:-.11em`, plus the mockup pulls the trailing `R` a further
  /// `-.13em` into the `P`.
  private var markText: some View {
    let fontSize = size * 0.34
    return HStack(spacing: 0) {
      Text("MEETP")
      Text("R").padding(.leading, -fontSize * 0.13)
    }
    .font(.MeetPR.display(size: fontSize, weight: .black))
    .tracking(-fontSize * 0.11)
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
