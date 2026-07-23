import CoreModels
import DesignSystem
import SwiftUI
import Testing

@testable import StudentKit

@Test func setVideoButtonOpensCameraOnlyForAnUnattachedSetOnCameraDevices() {
  #expect(SetVideoButtonDestination.resolve(for: nil, cameraAvailable: true) == .camera)
  #expect(SetVideoButtonDestination.resolve(for: nil, cameraAvailable: false) == .details)
}

@Test func setVideoButtonPreservesExistingUploadManagementRoutes() {
  #expect(SetVideoButtonDestination.resolve(for: .pending, cameraAvailable: true) == .details)
  #expect(SetVideoButtonDestination.resolve(for: .uploading, cameraAvailable: true) == .details)
  #expect(SetVideoButtonDestination.resolve(for: .uploaded, cameraAvailable: true) == .details)
  #expect(SetVideoButtonDestination.resolve(for: .failed, cameraAvailable: true) == .retry)
}

@Test func setVideoUploadIndicatorStyleMapsEveryUploadStatus() {
  #expect(SetVideoUploadIndicatorStyle.resolve(for: nil, progress: 0) == .unattached)
  #expect(
    SetVideoUploadIndicatorStyle.resolve(for: .pending, progress: 0.4)
      == .uploading(progress: 0))
  #expect(
    SetVideoUploadIndicatorStyle.resolve(for: .uploading, progress: 0.42)
      == .uploading(progress: 0.42))
  #expect(SetVideoUploadIndicatorStyle.resolve(for: .uploaded, progress: 1) == .uploaded)
  #expect(SetVideoUploadIndicatorStyle.resolve(for: .failed, progress: 0.7) == .failed)
}

@Test func setVideoUploadIndicatorClampsUploadProgress() {
  #expect(
    SetVideoUploadIndicatorStyle.resolve(for: .uploading, progress: -0.3)
      == .uploading(progress: 0))
  #expect(
    SetVideoUploadIndicatorStyle.resolve(for: .uploading, progress: 1.7)
      == .uploading(progress: 1))
}

@Test func setVideoUploadIndicatorStrokeColorsMatchDesignTokens() {
  #expect(SetVideoUploadIndicatorStyle.unattached.strokeColor == Color.MeetPR.fgTertiary)
  #expect(SetVideoUploadIndicatorStyle.uploaded.strokeColor == Color.MeetPR.green)
  #expect(SetVideoUploadIndicatorStyle.failed.strokeColor == Color.MeetPR.brandRed)
  #expect(SetVideoUploadIndicatorStyle.uploading(progress: 0.5).strokeColor == nil)
}

@Test func setVideoUploadIndicatorAccessibilityLabelsAreDistinct() {
  #expect(SetVideoUploadIndicatorStyle.unattached.accessibilityLabel == "未附视频")
  #expect(
    SetVideoUploadIndicatorStyle.uploading(progress: 0.65).accessibilityLabel == "视频上传中 65%")
  #expect(SetVideoUploadIndicatorStyle.uploaded.accessibilityLabel == "视频已上传")
  #expect(SetVideoUploadIndicatorStyle.failed.accessibilityLabel == "视频上传失败")
}
