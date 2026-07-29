import SwiftUI

public enum MeetPRTabIcon: Sendable {
  case today
  case training
  case growth
  case profile
}

public struct MeetPRTabBarItem<ID: Hashable & Sendable>: Identifiable, Sendable {
  public let id: ID
  public let title: String
  public let icon: MeetPRTabIcon
  public let badge: Int

  public init(
    id: ID,
    title: String,
    icon: MeetPRTabIcon,
    badge: Int = 0
  ) {
    self.id = id
    self.title = title
    self.icon = icon
    self.badge = badge
  }
}

public struct MeetPRTabBar<ID: Hashable & Sendable>: View {
  @Binding private var selection: ID
  private let items: [MeetPRTabBarItem<ID>]

  public init(
    selection: Binding<ID>,
    items: [MeetPRTabBarItem<ID>]
  ) {
    self._selection = selection
    self.items = items
  }

  public var body: some View {
    HStack(spacing: MeetPRSpacing.zero) {
      ForEach(items) { item in
        Button {
          selection = item.id
        } label: {
          VStack(spacing: MeetPRSpacing.space1) {
            MeetPRTabIconView(icon: item.icon)
              .frame(width: MeetPRSpacing.space6, height: MeetPRSpacing.space6)
              .overlay(alignment: .topTrailing) {
                if item.badge > 0 {
                  TabUnreadBadge(count: item.badge)
                    .offset(x: MeetPRSpacing.point10, y: -MeetPRSpacing.point6)
                }
              }

            Text(item.title)
              .font(.MeetPR.system(size: MeetPRFontMetrics.size11))
          }
          .foregroundStyle(
            selection == item.id
              ? Color.MeetPR.goldCTA
              : Color.MeetPR.textTertiary
          )
          .frame(maxWidth: .infinity)
          .frame(minHeight: MeetPRTabBarContract.contentHeight)
          .contentShape(.rect)
        }
        .buttonStyle(PressScaleButtonStyle(scale: 0.9))
        .accessibilityLabel(item.title)
        .accessibilityAddTraits(selection == item.id ? .isSelected : [])
      }
    }
    .padding(.top, MeetPRTabBarContract.topPadding)
    .background(Color.MeetPR.surfaceCard)
    .overlay(alignment: .top) {
      Rectangle()
        .fill(Color.MeetPR.borderSubtle)
        .frame(height: MeetPRSpacing.point1)
    }
  }
}

private enum MeetPRTabBarContract {
  /// 49pt visible rail + a typical 34pt home-indicator inset = the mockup's
  /// 83pt shell. `safeAreaInset` supplies the device-specific lower inset.
  static let contentHeight = MeetPRSpacing.minimumHitTarget
  static let topPadding: CGFloat = 5
}

private struct MeetPRTabIconView: View {
  let icon: MeetPRTabIcon

  var body: some View {
    switch icon {
    case .today:
      ZStack {
        TodayTabRings()
          .stroke(
            style: StrokeStyle(
              lineWidth: 2.3,
              lineCap: .round,
              lineJoin: .round
            )
          )
        TodayTabArrowStrokes()
          .stroke(style: iconStroke)
        TodayTabCenterCircle()
          .fill(.foreground)
        TodayTabArrowFill()
          .fill(.foreground)
      }
    case .training:
      TrainingTabIcon()
        .stroke(style: iconStroke)
    case .growth:
      GrowthTabIcon()
        .stroke(style: iconStroke)
    case .profile:
      ProfileTabIcon()
        .stroke(style: iconStroke)
    }
  }

  private var iconStroke: StrokeStyle {
    StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
  }
}

private struct TodayTabRings: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.addEllipse(in: rect.svgRect(x: 2.9, y: 3.9, width: 17.2, height: 17.2))
    path.addEllipse(in: rect.svgRect(x: 6.7, y: 7.7, width: 9.6, height: 9.6))
    return path
  }
}

private struct TodayTabArrowStrokes: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: rect.svgPoint(x: 14.4, y: 8.6))
    path.addLine(to: rect.svgPoint(x: 21.5, y: 2.3))
    path.move(to: rect.svgPoint(x: 22.6, y: 4.5))
    path.addLine(to: rect.svgPoint(x: 20.1, y: 3.5))
    path.addLine(to: rect.svgPoint(x: 19.5, y: 0.9))
    path.move(to: rect.svgPoint(x: 21.1, y: 5.8))
    path.addLine(to: rect.svgPoint(x: 18.6, y: 4.8))
    path.addLine(to: rect.svgPoint(x: 18, y: 2.2))
    return path
  }
}

private struct TrainingTabIcon: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: rect.svgPoint(x: 3, y: 9))
    path.addLine(to: rect.svgPoint(x: 3, y: 15))
    path.move(to: rect.svgPoint(x: 6, y: 7))
    path.addLine(to: rect.svgPoint(x: 6, y: 17))
    path.move(to: rect.svgPoint(x: 18, y: 7))
    path.addLine(to: rect.svgPoint(x: 18, y: 17))
    path.move(to: rect.svgPoint(x: 21, y: 9))
    path.addLine(to: rect.svgPoint(x: 21, y: 15))
    path.move(to: rect.svgPoint(x: 6, y: 12))
    path.addLine(to: rect.svgPoint(x: 18, y: 12))
    return path
  }
}

private struct GrowthTabIcon: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: rect.svgPoint(x: 4, y: 5))
    path.addLine(to: rect.svgPoint(x: 4, y: 19))
    path.addLine(to: rect.svgPoint(x: 20, y: 19))
    path.move(to: rect.svgPoint(x: 8, y: 15))
    path.addLine(to: rect.svgPoint(x: 11, y: 11))
    path.addLine(to: rect.svgPoint(x: 14, y: 14))
    path.addLine(to: rect.svgPoint(x: 18, y: 8))
    return path
  }
}

private struct ProfileTabIcon: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.addEllipse(in: rect.svgRect(x: 8.8, y: 4.8, width: 6.4, height: 6.4))
    path.move(to: rect.svgPoint(x: 5.5, y: 20))
    path.addCurve(
      to: rect.svgPoint(x: 18.5, y: 20),
      control1: rect.svgPoint(x: 5.5, y: 11.3),
      control2: rect.svgPoint(x: 18.5, y: 11.3)
    )
    return path
  }
}

private struct TodayTabCenterCircle: Shape {
  func path(in rect: CGRect) -> Path {
    Path(ellipseIn: rect.svgRect(x: 9.9, y: 10.9, width: 3.2, height: 3.2))
  }
}

private struct TodayTabArrowFill: Shape {
  func path(in rect: CGRect) -> Path {
    var path = Path()
    path.move(to: rect.svgPoint(x: 10.8, y: 12.2))
    path.addLine(to: rect.svgPoint(x: 16.2, y: 10.2))
    path.addLine(to: rect.svgPoint(x: 13.8, y: 7.2))
    path.closeSubpath()
    return path
  }
}

private struct TabUnreadBadge: View {
  let count: Int

  var body: some View {
    Text(count > 99 ? "99+" : count.formatted())
      .font(.MeetPR.mono(size: MeetPRFontMetrics.size9, weight: .bold))
      .foregroundStyle(Color.white)
      .padding(.horizontal, MeetPRSpacing.point3)
      .frame(minWidth: MeetPRSpacing.space4, minHeight: MeetPRSpacing.space4)
      .background(Color.MeetPR.dangerFill, in: .capsule)
  }
}

extension CGRect {
  fileprivate func svgPoint(x: CGFloat, y: CGFloat) -> CGPoint {
    CGPoint(
      x: minX + (x / 24) * width,
      y: minY + (y / 24) * height
    )
  }

  fileprivate func svgRect(
    x: CGFloat,
    y: CGFloat,
    width: CGFloat,
    height: CGFloat
  ) -> CGRect {
    CGRect(
      x: minX + (x / 24) * self.width,
      y: minY + (y / 24) * self.height,
      width: (width / 24) * self.width,
      height: (height / 24) * self.height
    )
  }
}
