import SwiftUI

public struct MeetPRTabBarItem<ID: Hashable>: Identifiable {
  public let id: ID
  public let title: String
  public let systemImage: String
  public let badge: Int

  public init(
    id: ID,
    title: String,
    systemImage: String,
    badge: Int = 0
  ) {
    self.id = id
    self.title = title
    self.systemImage = systemImage
    self.badge = badge
  }
}

public struct MeetPRTabBar<ID: Hashable>: View {
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
          VStack(spacing: MeetPRSpacing.point3) {
            Image(systemName: item.systemImage)
              .font(
                .MeetPR.system(
                  size: MeetPRFontMetrics.size20,
                  weight: selection == item.id ? .semibold : .regular
                )
              )
              .frame(height: MeetPRSpacing.space6)
              .overlay(alignment: .topTrailing) {
                if item.badge > 0 {
                  TabUnreadBadge(count: item.badge)
                    .offset(
                      x: MeetPRSpacing.point10,
                      y: -MeetPRSpacing.point6
                    )
                }
              }
            Text(item.title)
              .font(
                .MeetPR.system(
                  size: MeetPRFontMetrics.size10,
                  weight: .semibold
                )
              )
          }
          .foregroundStyle(
            selection == item.id
              ? Color.MeetPR.gold500
              : Color.MeetPR.textMuted
          )
          .frame(maxWidth: .infinity)
          .frame(minHeight: MeetPRSpacing.point48)
          .contentShape(.rect)
        }
        .buttonStyle(PressScaleButtonStyle(scale: 0.9))
        .accessibilityLabel(item.title)
        .accessibilityAddTraits(selection == item.id ? .isSelected : [])
      }
    }
    .padding(.horizontal, MeetPRSpacing.space2)
    .padding(.top, MeetPRSpacing.space2)
    .background(Color.MeetPR.bgBase)
    .overlay(alignment: .top) {
      Rectangle()
        .fill(Color.MeetPR.borderHairline)
        .frame(height: MeetPRSpacing.point1)
    }
  }
}

private struct TabUnreadBadge: View {
  let count: Int

  var body: some View {
    Text(count > 99 ? "99+" : count.formatted())
      .font(
        .MeetPR.system(
          size: MeetPRFontMetrics.size9,
          weight: .bold,
          design: .monospaced
        )
      )
      .foregroundStyle(Color.MeetPR.ctaTopHighlight)
      .padding(.horizontal, MeetPRSpacing.point3)
      .frame(
        minWidth: MeetPRSpacing.space4,
        minHeight: MeetPRSpacing.space4
      )
      .background(MeetPRSemanticTone.unread.color, in: .capsule)
  }
}
