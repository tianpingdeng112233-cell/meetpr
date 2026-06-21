import SwiftUI

/// A lightweight polyline mini-chart (e1RM trends, inline cards) with a brand-red
/// end dot. For richer interactive charts use `E1RMChart`; this is the compact form.
@available(iOS 17.0, macOS 14.0, *)
@MainActor
public struct Sparkline: View {
  private let points: [CGPoint]
  private let viewBox: CGSize
  private let lineColor: Color
  private let lineWidth: CGFloat
  private let showsEndDot: Bool

  public init(
    points: [CGPoint],
    viewBox: CGSize = CGSize(width: 600, height: 90),
    lineColor: Color = Color.MeetPR.fgPrimary,
    lineWidth: CGFloat = 1.5,
    showsEndDot: Bool = true
  ) {
    self.points = points
    self.viewBox = viewBox
    self.lineColor = lineColor
    self.lineWidth = lineWidth
    self.showsEndDot = showsEndDot
  }

  public var body: some View {
    GeometryReader { geo in
      let scaleX = geo.size.width / max(viewBox.width, 1)
      let scaleY = geo.size.height / max(viewBox.height, 1)
      ZStack {
        Path { path in
          for (index, point) in points.enumerated() {
            let scaled = CGPoint(x: point.x * scaleX, y: point.y * scaleY)
            if index == 0 { path.move(to: scaled) } else { path.addLine(to: scaled) }
          }
        }
        .stroke(lineColor, style: StrokeStyle(lineWidth: lineWidth, lineJoin: .round))

        if showsEndDot, let last = points.last {
          Circle()
            .fill(Color.MeetPR.brandRed)
            .frame(width: 8, height: 8)
            .position(x: last.x * scaleX, y: last.y * scaleY)
        }
      }
    }
    .accessibilityHidden(true)
  }

  /// Parse "0,90 60,76 120,70" style point strings (matches design source).
  public static func parse(_ raw: String) -> [CGPoint] {
    raw.split(separator: " ").compactMap { pair in
      let components = pair.split(separator: ",")
      guard components.count == 2, let x = Double(components[0]), let y = Double(components[1])
      else { return nil }
      return CGPoint(x: x, y: y)
    }
  }
}

#Preview("Sparkline") {
  Sparkline(
    points: Sparkline.parse(
      "0,80 60,76 120,70 180,72 240,58 300,52 360,54 420,40 480,32 540,24 600,10")
  )
  .frame(height: 90)
  .padding()
  .background(Color.MeetPR.bg)
  .preferredColorScheme(.dark)
}
