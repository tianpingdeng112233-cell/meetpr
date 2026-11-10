import DesignSystem
import SwiftUI

struct AllDayTimelineNode: View {
  let node: AllDayExercise.Node
  let last: Bool

  private var fill: AnyShapeStyle {
    switch node {
    case .completed: AnyShapeStyle(Color.MeetPR.success)
    case .pending: AnyShapeStyle(Color.MeetPR.borderStrong)
    case .current:
      AnyShapeStyle(
        LinearGradient(
          colors: [Color.MeetPR.goldGradientStart, Color.MeetPR.goldGradientEnd],
          startPoint: .top, endPoint: .bottom))
    }
  }

  var body: some View {
    Color.clear
      .frame(width: 22)
      .overlay(alignment: .top) {
        if !last { AllDayTimelineConnector().stroke(fill, lineWidth: 3) }
      }
      .overlay(alignment: .top) {
        Circle()
          .fill(node == .pending ? AnyShapeStyle(Color.MeetPR.textDim) : fill)
          .overlay {
            if node == .completed {
              Image(systemName: "checkmark")
                .font(.MeetPR.system(size: MeetPRFontMetrics.size12, weight: .bold))
                .foregroundStyle(Color.MeetPR.inkOnCTAFill)
            }
          }
          .frame(width: 22, height: 22)
          .background {
            if node == .current { Circle().fill(Color.MeetPR.goldRGB.opacity(0.16)).padding(-4) }
          }
          .padding(.top, MeetPRSpacing.space2)
      }
      .accessibilityHidden(true)
  }
}

/// Draw through the inter-row spacing to the next node's center; the next node covers the endpoint.
struct AllDayTimelineConnector: Shape {
  func path(in rect: CGRect) -> Path {
    let center = MeetPRSpacing.space2 + 11
    return Path { path in
      path.move(to: CGPoint(x: rect.midX, y: rect.minY + center))
      path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY + MeetPRSpacing.space4 + center))
    }
  }
}
