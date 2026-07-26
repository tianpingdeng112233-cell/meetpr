import DesignSystem
import SwiftUI

/// Replaces the floating system tab bar with the design's flat 4-tab bar
/// (same treatment as the coach side): hidden system bar + a
/// `MeetPRTabBar` safe-area inset with the spec's 0.9 press scale.
@available(iOS 17.0, macOS 14.0, *)
struct StudentFlatTabBarModifier: ViewModifier {
  @Binding var selection: StudentTab
  let profileBadge: Int

  func body(content: Content) -> some View {
    #if os(iOS)
      content
        .toolbar(.hidden, for: .tabBar)
        .safeAreaInset(edge: .bottom, spacing: MeetPRSpacing.zero) {
          MeetPRTabBar(
            selection: $selection,
            items: [
              MeetPRTabBarItem(id: StudentTab.today, title: "今日", systemImage: "house"),
              MeetPRTabBarItem(id: StudentTab.training, title: "训练", systemImage: "dumbbell"),
              MeetPRTabBarItem(
                id: StudentTab.growth, title: "成长",
                systemImage: "chart.line.uptrend.xyaxis"
              ),
              MeetPRTabBarItem(
                id: StudentTab.profile, title: "我的", systemImage: "person",
                badge: profileBadge
              ),
            ]
          )
        }
    #else
      content
    #endif
  }
}
