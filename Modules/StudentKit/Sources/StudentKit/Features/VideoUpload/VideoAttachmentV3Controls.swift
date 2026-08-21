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
      // On-demand confirmation only inside the edit sheet (David 2026-08-06):
      // the glanceable surfaces stay free of upload chrome. There is no
      // retake affordance by design (David 2026-08-07): the video documents
      // the set that happened — a set, once done, is done.
      VStack(alignment: .trailing, spacing: MeetPRSpacing.point7) {
        HStack(spacing: MeetPRSpacing.point10) {
          actionButton(
            StudentStrings.localized(.videoAttachmentV3Controls004), systemImage: "photo",
            action: onLibrary)
          actionButton(
            StudentStrings.localized(.videoAttachmentV3Controls005), systemImage: "trash",
            action: onDelete
          )
          .disabled(!canDelete)
        }
        Label(
          delivered
            ? StudentStrings.localized(.videoAttachmentV3Controls006)
            : StudentStrings.localized(.videoAttachmentV3Controls007),
          systemImage: delivered ? "checkmark.circle" : "arrow.up.circle.dotted"
        )
        .font(.MeetPR.body(size: MeetPRFontMetrics.size12, weight: .regular))
        .foregroundStyle(Color.MeetPR.goldRGB.opacity(0.45))
      }

    case .failed:
      HStack(spacing: MeetPRSpacing.space2) {
        Label(
          StudentStrings.localized(.videoAttachmentV3Controls008),
          systemImage: "exclamationmark.triangle.fill"
        )
        .font(.MeetPR.body(size: MeetPRFontMetrics.size12, weight: .medium))
        .foregroundStyle(Color.MeetPR.danger)
        actionButton(
          StudentStrings.localized(.videoAttachmentV3Controls009), systemImage: "arrow.clockwise",
          action: onRetry)
        actionButton(
          StudentStrings.localized(.videoAttachmentV3Controls005), systemImage: "trash",
          action: onDelete)
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
