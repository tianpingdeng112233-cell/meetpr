import CoreModels
import DesignSystem
import SwiftUI

enum SetVideoUploadIndicatorStyle: Equatable, Sendable {
  case unattached
  case pending
  case uploading
  case uploaded
  case failed

  static func resolve(for status: VideoAttachment.Status?) -> SetVideoUploadIndicatorStyle {
    switch status {
    case .none:
      .unattached
    case .pending:
      .pending
    case .uploading:
      .uploading
    case .uploaded:
      .uploaded
    case .failed:
      .failed
    }
  }

  var systemImage: String {
    switch self {
    case .unattached:
      "video"
    case .pending:
      "clock.arrow.circlepath"
    case .uploading:
      "arrow.up.circle.fill"
    case .uploaded:
      "checkmark.circle.fill"
    case .failed:
      "exclamationmark.triangle.fill"
    }
  }

  var accessibilityLabel: String {
    switch self {
    case .unattached:
      "未附视频"
    case .pending:
      "视频等待上传"
    case .uploading:
      "视频上传中"
    case .uploaded:
      "视频已上传"
    case .failed:
      "视频上传失败"
    }
  }

  var accentColor: Color {
    switch self {
    case .unattached:
      Color.MeetPR.fgTertiary
    case .pending, .uploading:
      Color.MeetPR.brandRed
    case .uploaded:
      Color.MeetPR.green
    case .failed:
      Color.MeetPR.amber
    }
  }

  /// The override only applies to `.unattached`; status states keep their accent.
  func color(unattached unattachedColor: Color) -> Color {
    self == .unattached ? unattachedColor : accentColor
  }
}

@available(iOS 17.0, macOS 14.0, *)
struct SetVideoUploadIndicator: View {
  let status: VideoAttachment.Status?
  let size: CGFloat
  /// Color for the `.unattached` glyph only; status states keep the style's
  /// accent. The expanded action button preserves its pre-existing primary
  /// tint while the compact row stays tertiary.
  var unattachedColor: Color = Color.MeetPR.fgTertiary

  private var style: SetVideoUploadIndicatorStyle {
    .resolve(for: status)
  }

  var body: some View {
    Image(systemName: style.systemImage)
      .font(.system(size: size))
      .foregroundStyle(style.color(unattached: unattachedColor))
      .accessibilityLabel(style.accessibilityLabel)
  }
}
