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
  #expect(SetVideoUploadIndicatorStyle.resolve(for: .pending, progress: 0.4) == .attached)
  #expect(SetVideoUploadIndicatorStyle.resolve(for: .uploading, progress: 0.42) == .attached)
  #expect(SetVideoUploadIndicatorStyle.resolve(for: .uploaded, progress: 1) == .attached)
  #expect(SetVideoUploadIndicatorStyle.resolve(for: .failed, progress: 0.7) == .failed)
}

@Test func setVideoUploadIndicatorIgnoresUploadProgress() {
  #expect(SetVideoUploadIndicatorStyle.resolve(for: .uploading, progress: -0.3) == .attached)
  #expect(SetVideoUploadIndicatorStyle.resolve(for: .uploading, progress: 1.7) == .attached)
}

@Test func setVideoUploadIndicatorStrokeColorsMatchDesignTokens() {
  #expect(SetVideoUploadIndicatorStyle.unattached.strokeColor == Color.MeetPR.textMuted)
  #expect(SetVideoUploadIndicatorStyle.attached.strokeColor == Color.MeetPR.textMuted)
  #expect(SetVideoUploadIndicatorStyle.failed.strokeColor == Color.MeetPR.danger)
}

@Test func setVideoUploadIndicatorAccessibilityLabelsAreDistinct() {
  #expect(SetVideoUploadIndicatorStyle.unattached.accessibilityLabel == "未附视频")
  #expect(SetVideoUploadIndicatorStyle.attached.accessibilityLabel == "已附视频")
  #expect(SetVideoUploadIndicatorStyle.failed.accessibilityLabel == "视频上传失败")
}
