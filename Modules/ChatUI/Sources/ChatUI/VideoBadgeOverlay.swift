import DesignSystem
import SwiftUI

/// The recording preview and ImageRenderer both position the card in the actual video rectangle.
public struct VideoBadgeExportOverlay: View {
  let info: VideoBadgeInfo
  let size: CGSize

  public init(info: VideoBadgeInfo, size: CGSize) {
    self.info = info
    self.size = size
  }

  public var body: some View {
    let layout = VideoBadgeLayout(size: size)
    ZStack(alignment: .bottomLeading) {
      Color.clear
      if info.hasContent {
        VideoBadgeCard(presentation: .init(info: info, mode: .export), scale: layout.scale)
          .padding(.leading, layout.exportInsets.x)
          .padding(.bottom, layout.exportInsets.y)
      }
    }
    .frame(width: size.width, height: size.height)
    .allowsHitTesting(false)
  }
}

public struct VideoBadgeOverlay: View {
  let info: VideoBadgeInfo
  @Binding var isExpanded: Bool
  var allowsExpansion = true
  var scale: CGFloat = 1

  public init(info: VideoBadgeInfo, isExpanded: Binding<Bool>, size: CGSize) {
    self.info = info
    _isExpanded = isExpanded
    scale = VideoBadgeLayout(size: size).scale
  }

  init(
    info: VideoBadgeInfo, isExpanded: Binding<Bool>, allowsExpansion: Bool = true,
    scale: CGFloat = 1
  ) {
    self.info = info
    _isExpanded = isExpanded
    self.allowsExpansion = allowsExpansion
    self.scale = scale
  }

  public var body: some View {
    if allowsExpansion {
      Button {
        isExpanded.toggle()
      } label: {
        if isExpanded {
          VideoBadgeCard(presentation: .init(info: info, mode: .replay), scale: scale)
        } else {
          VideoBadgeLogoMark(size: max(61 * scale, MeetPRSpacing.minimumHitTarget))
            .scaleEffect(100 / 78.0)
            .shadow(color: .black.opacity(0.38), radius: 9, y: 4)
        }
      }
      .buttonStyle(.plain)
      .padding(.leading, 44 * scale)
      .accessibilityLabel(
        isExpanded ? ChatStrings.collapseVideoBadge : ChatStrings.expandVideoBadge
      )
      .accessibilityIdentifier(
        isExpanded ? "feedback.video.badge.expanded" : "feedback.video.badge.collapsed")
    } else {
      VideoBadgeLogoMark(size: MeetPRSpacing.minimumHitTarget)
        .shadow(color: .black.opacity(0.38), radius: 9, y: 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        .accessibilityHidden(true)
    }
  }
}
