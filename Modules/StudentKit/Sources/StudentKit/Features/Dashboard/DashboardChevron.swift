import SwiftUI

enum DashboardChevronDirection: Sendable {
  case down
  case right
}

struct DashboardChevron: Shape {
  let direction: DashboardChevronDirection

  func path(in rect: CGRect) -> Path {
    var path = Path()
    switch direction {
    case .down:
      path.move(to: CGPoint(x: rect.width * 0.25, y: rect.height * 0.375))
      path.addLine(to: CGPoint(x: rect.width * 0.5, y: rect.height * 0.625))
      path.addLine(to: CGPoint(x: rect.width * 0.75, y: rect.height * 0.375))
    case .right:
      path.move(to: CGPoint(x: rect.width * 0.375, y: rect.height * 0.25))
      path.addLine(to: CGPoint(x: rect.width * 0.625, y: rect.height * 0.5))
      path.addLine(to: CGPoint(x: rect.width * 0.375, y: rect.height * 0.75))
    }
    return path
  }
}
