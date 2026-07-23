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

/// Visual language (David 2026-07-11): always the same camera glyph, only the
/// stroke color changes — gray when no video, a progress-proportional
/// foreground sweep while uploading, green on success, red on failure.
enum SetVideoUploadIndicatorStyle: Equatable, Sendable {
  case unattached
  case uploading(progress: Double)
  case uploaded
  case failed

  static func resolve(
    for status: VideoAttachment.Status?, progress: Double
  ) -> SetVideoUploadIndicatorStyle {
    switch status {
    case .none:
      .unattached
    case .pending:
      .uploading(progress: 0)
    case .uploading:
      .uploading(progress: min(max(progress, 0), 1))
    case .uploaded:
      .uploaded
    case .failed:
      .failed
    }
  }

  /// Single stroke color; nil for `.uploading`, which renders two-tone.
  var strokeColor: Color? {
    switch self {
    case .unattached:
      Color.MeetPR.fgTertiary
    case .uploading:
      nil
    case .uploaded:
      Color.MeetPR.green
    case .failed:
      Color.MeetPR.brandRed
    }
  }

  var accessibilityLabel: String {
    switch self {
    case .unattached:
      "未附视频"
    case .uploading(let progress):
      "视频上传中 \(Int((progress * 100).rounded()))%"
    case .uploaded:
      "视频已上传"
    case .failed:
      "视频上传失败"
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
      if case .uploading(let progress) = style {
        glyph(Color.MeetPR.fgTertiary)
          .overlay {
            // Left-to-right sweep: the fgPrimary glyph is revealed across the
            // real part-upload fraction from VideoAttachmentViewModel.
            glyph(Color.MeetPR.fgPrimary)
              .mask(alignment: .leading) {
                GeometryReader { geo in
                  Rectangle().frame(width: geo.size.width * progress)
                }
              }
          }
      } else {
        glyph(style.strokeColor ?? Color.MeetPR.fgTertiary)
      }
    }
    .accessibilityLabel(style.accessibilityLabel)
  }

  private func glyph(_ color: Color) -> some View {
    Image(systemName: "video")
      .font(.system(size: size))
      .foregroundStyle(color)
  }
}
