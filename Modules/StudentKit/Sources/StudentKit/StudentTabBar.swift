import DesignSystem
import SwiftUI

extension View {
  @ViewBuilder
  func meetPRStudentTabBar(
    selection: Binding<StudentTab>,
    profileBadge: Int
  ) -> some View {
    #if os(iOS)
      toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom, spacing: MeetPRSpacing.zero) {
          MeetPRTabBar(
            selection: selection,
            items: [
              MeetPRTabBarItem(id: .today, title: "今日", systemImage: "house"),
              MeetPRTabBarItem(id: .training, title: "训练", systemImage: "dumbbell.fill"),
              MeetPRTabBarItem(
                id: .growth,
                title: "成长",
                systemImage: "chart.line.uptrend.xyaxis"
              ),
              MeetPRTabBarItem(
                id: .profile,
                title: "我的",
                systemImage: "person",
                badge: profileBadge
              ),
            ]
          )
        }
    #else
      self
    #endif
  }
}

/// Keeps every page mounted (state and tasks intact, mirroring `TabView`)
/// while showing only the selected one.
@available(iOS 17.0, macOS 14.0, *)
struct StudentPageVisibility: ViewModifier {
  let tab: StudentTab
  let selection: StudentTab

  func body(content: Content) -> some View {
    let isActive = tab == selection
    content
      .opacity(isActive ? 1 : 0)
      .allowsHitTesting(isActive)
      .accessibilityHidden(!isActive)
      .zIndex(isActive ? 1 : 0)
  }
}
