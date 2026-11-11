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
        if !last {
          AllDayTimelineConnector().stroke(fill, lineWidth: 3)
            .padding(.top, MeetPRSpacing.space2 + 11)
            .padding(.bottom, -(MeetPRSpacing.space4 + MeetPRSpacing.space2 + 11))
        }
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

/// The caller extends the layout to the next node so the stroke and gradient share one bounds.
struct AllDayTimelineConnector: Shape {
  func path(in rect: CGRect) -> Path {
    Path { path in
      path.move(to: CGPoint(x: rect.midX, y: rect.minY))
      path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
    }
  }
}
