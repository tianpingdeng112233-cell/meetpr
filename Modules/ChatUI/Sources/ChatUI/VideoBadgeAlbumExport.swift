import DesignSystem
import Foundation
import SwiftUI

@MainActor @Observable
public final class VideoBadgeAlbumExport {
  public private(set) var isExporting = false
  fileprivate var showingExportFailure = false
  fileprivate var exportFailureMessage = ""
  fileprivate var showingSavedToast = false
  fileprivate var exportTask: Task<Void, Never>?

  public init() {}

  public func start(sourceURL: URL, badge: VideoBadgeInfo) {
    #if os(iOS)
      guard !isExporting else { return }
      isExporting = true
      showingSavedToast = false
      exportTask = Task { [self] in
        do {
          let outputURL = try await VideoBadgeExporter().export(
            sourceURL: sourceURL,
            badge: badge
          )
          defer { try? FileManager.default.removeItem(at: outputURL) }
          try Task.checkCancellation()
          try await VideoBadgePhotoLibrary.save(outputURL)
          try Task.checkCancellation()
          showingSavedToast = true
          try? await Task.sleep(for: .seconds(2.5))
          showingSavedToast = false
        } catch is CancellationError {
          showingSavedToast = false
        } catch VideoBadgePhotoLibraryError.permissionDenied {
          exportFailureMessage = ChatStrings.videoExportPhotoPermissionDenied
          showingExportFailure = true
        } catch {
          exportFailureMessage = ChatStrings.videoExportFailureMessage
          showingExportFailure = true
        }
        isExporting = false
        exportTask = nil
      }
    #endif
  }
}

public struct VideoBadgeSaveButton: View {
  let isExporting: Bool
  let action: () -> Void

  public init(isExporting: Bool, action: @escaping () -> Void) {
    self.isExporting = isExporting
    self.action = action
  }

  public var body: some View {
    Button(action: action) {
      Group {
        if isExporting {
          ProgressView()
            .tint(.white)
        } else {
          Image(systemName: "arrow.down.to.line")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(.white)
        }
      }
      .frame(width: 36, height: 36)
      .background(.ultraThinMaterial, in: .circle)
      .overlay {
        Circle().stroke(Color.white.opacity(0.18), lineWidth: 1)
      }
    }
    .disabled(isExporting)
    .accessibilityLabel(
      isExporting ? ChatStrings.videoExporting : ChatStrings.videoExport
    )
    .accessibilityIdentifier("feedback.video.export")
  }
}

public struct VideoBadgeExportFeedback: ViewModifier {
  @Bindable var job: VideoBadgeAlbumExport

  public init(job: VideoBadgeAlbumExport) { self.job = job }

  public func body(content: Content) -> some View {
    content
      .overlay(alignment: .top) {
        if job.showingSavedToast {
          Text(ChatStrings.videoExportSaved)
            .font(.MeetPR.body(size: MeetPRFontMetrics.size13, weight: .semibold))
            .foregroundStyle(Color.MeetPR.textPrimary)
            .padding(.horizontal, MeetPRSpacing.space4)
            .padding(.vertical, MeetPRSpacing.point10)
            .background(Color.MeetPR.bgInset.opacity(0.96), in: .capsule)
            .overlay {
              Capsule().stroke(Color.MeetPR.borderStrong, lineWidth: 1)
            }
            .padding(.top, MeetPRSpacing.point56)
            .accessibilityIdentifier("feedback.video.exportSaved")
        }
      }
      .alert(ChatStrings.videoExportFailed, isPresented: $job.showingExportFailure) {
        Button(ChatStrings.close, role: .cancel) {}
      } message: {
        Text(job.exportFailureMessage)
      }
      .onDisappear { job.exportTask?.cancel() }
  }
}
