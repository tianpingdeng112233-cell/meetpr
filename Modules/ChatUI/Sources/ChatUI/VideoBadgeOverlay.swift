import DesignSystem
import SwiftUI

@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct VideoBadgeOverlay: View {
  let info: VideoBadgeInfo
  @Binding var isExpanded: Bool
  /// Compact hosts (the 270pt workbench stage) pin the badge to the collapsed
  /// logo mark: an expanded card cannot fit there without covering the central
  /// playback button, and the set data is already shown beside the player.
  var allowsExpansion: Bool = true

  var body: some View {
    GeometryReader { proxy in
      VStack {
        Spacer()
        HStack {
          Spacer()
          if allowsExpansion {
            Button {
              isExpanded.toggle()
            } label: {
              badgeContent(containerWidth: proxy.size.width, expanded: isExpanded)
            }
            .accessibilityLabel(
              isExpanded ? ChatStrings.collapseVideoBadge : ChatStrings.expandVideoBadge
            )
            .accessibilityIdentifier(
              isExpanded ? "feedback.video.badge.expanded" : "feedback.video.badge.collapsed"
            )
          } else {
            badgeContent(containerWidth: proxy.size.width, expanded: false)
              .accessibilityHidden(true)
          }
          Spacer()
        }
      }
    }
  }

  @ViewBuilder
  private func badgeContent(containerWidth: CGFloat, expanded: Bool) -> some View {
    if expanded {
      VideoBadgeCard(
        presentation: VideoBadgePresentation(info: info),
        width: VideoBadgeLayout.screenCardWidth(containerWidth: containerWidth),
        includesCoachAttribution: false
      )
      .environment(\.colorScheme, .dark)
    } else {
      VideoBadgeLogoMark(size: MeetPRSpacing.minimumHitTarget)
        .shadow(color: .black.opacity(0.38), radius: 9, y: 4)
    }
  }
}
