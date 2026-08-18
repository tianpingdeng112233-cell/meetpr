import CoreModels
import DesignSystem
import SwiftUI

enum SetVideoButtonDestination: Equatable, Sendable {
  case camera
  case details
  case retry

  static func resolve(
    for status: VideoAttachment.Status?,
    cameraAvailable: Bool
  ) -> SetVideoButtonDestination {
    switch status {
    case .none:
      cameraAvailable ? .camera : .details
    case .failed:
      .retry
    case .pending, .uploading, .uploaded:
      .details
    }
  }
}

/// Upload work is deliberately silent: every attached nonterminal state uses
/// the same neutral camera glyph; only terminal failure changes appearance.
enum SetVideoUploadIndicatorStyle: Equatable, Sendable {
  case unattached
  case attached
  case failed

  static func resolve(
    for status: VideoAttachment.Status?, progress: Double
  ) -> SetVideoUploadIndicatorStyle {
    switch status {
    case .none:
      .unattached
    case .pending, .uploading, .uploaded:
      .attached
    case .failed:
      .failed
    }
  }

  var strokeColor: Color {
    switch self {
    case .unattached:
      Color.MeetPR.textMuted
    case .attached:
      Color.MeetPR.textMuted
    case .failed:
      Color.MeetPR.danger
    }
  }

  var accessibilityLabel: String {
    switch self {
    case .unattached:
      StudentStrings.localized(.setVideoUploadIndicator001)
    case .attached:
      StudentStrings.localized(.setVideoUploadIndicator002)
    case .failed:
      StudentStrings.localized(.setVideoUploadIndicator003)
    }
  }
}

@available(iOS 17.0, macOS 14.0, *)
struct SetVideoUploadIndicator: View {
  let status: VideoAttachment.Status?
  let progress: Double
  let size: CGFloat

  private var style: SetVideoUploadIndicatorStyle {
    .resolve(for: status, progress: progress)
  }

  var body: some View {
    Group {
      glyph(style.strokeColor)
    }
    .accessibilityLabel(style.accessibilityLabel)
  }

  private func glyph(_ color: Color) -> some View {
    Image(systemName: "video")
      .font(.system(size: size))
      .foregroundStyle(color)
  }
}
