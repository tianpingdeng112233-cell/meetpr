import DesignSystem
import SwiftUI

enum VideoAttachmentV3State: Equatable {
  case choices(cameraAvailable: Bool)
  case attached(cameraAvailable: Bool, canDelete: Bool, delivered: Bool)
  case failed
}

@available(iOS 17.0, macOS 14.0, *)
struct VideoAttachmentV3Controls: View {
  let state: VideoAttachmentV3State
  let onCamera: @MainActor () -> Void
  let onLibrary: @MainActor () -> Void
  let onCancel: @MainActor () -> Void
  let onRetry: @MainActor () -> Void
  let onDelete: @MainActor () -> Void

  var body: some View {
    switch state {
    case .choices(let cameraAvailable):
      HStack(spacing: MeetPRSpacing.point10) {
        actionButton(
          "拍摄",
          systemImage: "video",
          isEnabled: cameraAvailable,
          action: onCamera
        )
        actionButton("相册", systemImage: "photo", action: onLibrary)
      }

    case .attached(let cameraAvailable, let canDelete, let delivered):
      // On-demand confirmation only inside the edit sheet (David 2026-08-06):
      // the glanceable surfaces stay free of upload chrome.
      VStack(alignment: .trailing, spacing: MeetPRSpacing.point7) {
        HStack(spacing: MeetPRSpacing.point10) {
          actionButton("重拍", systemImage: "video", isEnabled: cameraAvailable, action: onCamera)
          actionButton("更换", systemImage: "photo", action: onLibrary)
          actionButton("删除", systemImage: "trash", action: onDelete)
            .disabled(!canDelete)
        }
        Label(
          delivered ? "已送达教练" : "还在路上",
          systemImage: delivered ? "checkmark.circle" : "arrow.up.circle.dotted"
        )
        .font(.MeetPR.body(size: MeetPRFontMetrics.size12, weight: .regular))
        .foregroundStyle(Color.MeetPR.goldRGB.opacity(0.45))
      }

    case .failed:
      HStack(spacing: MeetPRSpacing.space2) {
        Label("上传失败", systemImage: "exclamationmark.triangle.fill")
          .font(.MeetPR.body(size: MeetPRFontMetrics.size12, weight: .medium))
          .foregroundStyle(Color.MeetPR.danger)
        actionButton("重试", systemImage: "arrow.clockwise", action: onRetry)
        actionButton("删除", systemImage: "trash", action: onDelete)
      }
    }
  }

  private func actionButton(
    _ title: String,
    systemImage: String,
    isEnabled: Bool = true,
    action: @escaping @MainActor () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(spacing: MeetPRSpacing.point7) {
        Image(systemName: systemImage)
          .font(.system(size: MeetPRFontMetrics.size20, weight: .regular))
        Text(title)
          .font(.MeetPR.body(size: MeetPRFontMetrics.size15, weight: .semibold))
      }
      .foregroundStyle(Color.MeetPR.goldRGB.opacity(isEnabled ? 0.72 : 0.30))
      .padding(.horizontal, MeetPRSpacing.point15)
      .padding(.vertical, MeetPRSpacing.space2)
      .overlay {
        RoundedRectangle(cornerRadius: MeetPRRadius.control)
          .stroke(Color.MeetPR.goldRGB.opacity(isEnabled ? 0.24 : 0.12), lineWidth: 1)
      }
      .frame(minHeight: MeetPRSpacing.minimumHitTarget)
    }
    .buttonStyle(PressScaleButtonStyle())
    .disabled(!isEnabled)
  }
}
