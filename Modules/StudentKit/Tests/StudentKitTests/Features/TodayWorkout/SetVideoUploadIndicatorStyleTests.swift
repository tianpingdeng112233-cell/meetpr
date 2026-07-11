import CoreModels
import DesignSystem
import SwiftUI
import Testing

@testable import StudentKit

@Test func setVideoUploadIndicatorStyleMapsEveryUploadStatus() {
  #expect(SetVideoUploadIndicatorStyle.resolve(for: nil) == .unattached)
  #expect(SetVideoUploadIndicatorStyle.resolve(for: .pending) == .pending)
  #expect(SetVideoUploadIndicatorStyle.resolve(for: .uploading) == .uploading)
  #expect(SetVideoUploadIndicatorStyle.resolve(for: .uploaded) == .uploaded)
  #expect(SetVideoUploadIndicatorStyle.resolve(for: .failed) == .failed)
}

@Test func setVideoUploadIndicatorStyleUsesDistinctStatusSymbols() {
  #expect(SetVideoUploadIndicatorStyle.unattached.systemImage == "video")
  #expect(SetVideoUploadIndicatorStyle.pending.systemImage == "clock.arrow.circlepath")
  #expect(SetVideoUploadIndicatorStyle.uploading.systemImage == "arrow.up.circle.fill")
  #expect(SetVideoUploadIndicatorStyle.uploaded.systemImage == "checkmark.circle.fill")
  #expect(SetVideoUploadIndicatorStyle.failed.systemImage == "exclamationmark.triangle.fill")
}

@Test func setVideoUploadIndicatorUnattachedOverrideOnlyAffectsUnattached() {
  #expect(
    SetVideoUploadIndicatorStyle.unattached.color(unattached: Color.MeetPR.fgPrimary)
      == Color.MeetPR.fgPrimary)
  #expect(
    SetVideoUploadIndicatorStyle.unattached.color(unattached: Color.MeetPR.fgTertiary)
      == Color.MeetPR.fgTertiary)
  for style: SetVideoUploadIndicatorStyle in [.pending, .uploading, .uploaded, .failed] {
    #expect(style.color(unattached: Color.MeetPR.fgPrimary) == style.accentColor)
  }
}

@Test func setVideoUploadIndicatorStatusAccentsMatchDesignTokens() {
  #expect(SetVideoUploadIndicatorStyle.uploaded.accentColor == Color.MeetPR.green)
  #expect(SetVideoUploadIndicatorStyle.failed.accentColor == Color.MeetPR.amber)
  #expect(SetVideoUploadIndicatorStyle.pending.accentColor == Color.MeetPR.brandRed)
  #expect(SetVideoUploadIndicatorStyle.uploading.accentColor == Color.MeetPR.brandRed)
}
