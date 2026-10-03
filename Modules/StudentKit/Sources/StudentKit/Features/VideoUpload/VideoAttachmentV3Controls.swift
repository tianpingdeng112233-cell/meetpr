import CoreModels
import DesignSystem
import SwiftUI

enum VideoAttachmentV3State: Equatable {
  case choices(cameraAvailable: Bool)
  case preparing
  case attached(cameraAvailable: Bool, canDelete: Bool, delivered: Bool)
  case failed

  static func resolve(
    status: VideoAttachment.Status?,
    isPreparing: Bool,
    cameraAvailable: Bool
  ) -> Self {
    if isPreparing {
      return .preparing
    }
    guard let status else {
      return .choices(cameraAvailable: cameraAvailable)
    }
    switch status {
    case .pending, .uploading:
      return .attached(cameraAvailable: cameraAvailable, canDelete: true, delivered: false)
    case .uploaded:
      return .attached(cameraAvailable: cameraAvailable, canDelete: true, delivered: true)
    case .failed:
      return .failed
    }
  }
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
          StudentStrings.localized(.videoAttachmentV3Controls001),
          systemImage: "video",
          isEnabled: cameraAvailable,
          action: onCamera
        )
        actionButton(
          StudentStrings.localized(.videoAttachmentV3Controls002), systemImage: "photo",
          action: onLibrary)
      }

    case .preparing:
      HStack(spacing: MeetPRSpacing.space2) {
        ProgressView()
        Text(StudentStrings.localized(.videoAttachmentV3Controls003))
          .font(.MeetPR.body(size: MeetPRFontMetrics.size12, weight: .medium))
          .foregroundStyle(Color.MeetPR.goldRGB.opacity(0.60))
      }

    case .attached(_, let canDelete, let delivered):
      VideoAttachmentActionsRow(
        delivered: delivered, failed: false, canDelete: canDelete,
        replace: onLibrary, delete: onDelete, retry: onRetry)
    case .failed:
      VideoAttachmentActionsRow(
        delivered: false, failed: true, canDelete: true,
        replace: onLibrary, delete: onDelete, retry: onRetry)
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

private struct VideoAttachmentActionsRow: View {
  let delivered: Bool
  let failed: Bool
  let canDelete: Bool
  let replace: @MainActor () -> Void
  let delete: @MainActor () -> Void
  let retry: @MainActor () -> Void

  var body: some View {
    ViewThatFits(in: .horizontal) {
      HStack(spacing: MeetPRSpacing.sm) {
        VideoAttachmentStatus(delivered: delivered, failed: failed, retry: retry)
        Spacer(minLength: MeetPRSpacing.sm)
        VideoAttachmentEditButtons(canDelete: canDelete, replace: replace, delete: delete)
      }
      VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
        VideoAttachmentStatus(delivered: delivered, failed: failed, retry: retry)
        VideoAttachmentEditButtons(canDelete: canDelete, replace: replace, delete: delete)
          .frame(maxWidth: .infinity, alignment: .trailing)
      }
    }
  }
}

private struct VideoAttachmentStatus: View {
  let delivered: Bool
  let failed: Bool
  let retry: @MainActor () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.xs) {
      Label(
        StudentStrings.localized(
          failed
            ? .videoAttachmentV3Controls008
            : (delivered ? .videoAttachmentV3Controls006 : .videoAttachmentV3Controls007)),
        systemImage: failed
          ? "exclamationmark.triangle.fill"
          : (delivered ? "checkmark.circle" : "arrow.up.circle.dotted")
      )
      .font(.MeetPR.footnote)
      .foregroundStyle(failed ? Color.MeetPR.danger : Color.MeetPR.textSecondary)
      if failed {
        Button(StudentStrings.localized(.videoAttachmentV3Controls009), action: retry)
          .font(.MeetPR.footnote)
          .frame(minHeight: MeetPRSpacing.minimumHitTarget)
      }
    }
    .fixedSize(horizontal: false, vertical: true)
  }
}

private struct VideoAttachmentEditButtons: View {
  let canDelete: Bool
  let replace: @MainActor () -> Void
  let delete: @MainActor () -> Void

  var body: some View {
    HStack(spacing: MeetPRSpacing.sm) {
      Button(StudentStrings.localized(.videoAttachmentV3Controls004), action: replace)
      Button(StudentStrings.localized(.videoAttachmentV3Controls005), action: delete)
        .disabled(!canDelete)
    }
    .font(.MeetPR.footnote)
    .buttonStyle(.bordered)
    .controlSize(.regular)
    .fixedSize(horizontal: true, vertical: false)
    .frame(minHeight: MeetPRSpacing.minimumHitTarget)
  }
}
