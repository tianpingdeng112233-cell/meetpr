import CoreModels
import SwiftUI
import Testing
import ViewInspector

@testable import StudentKit

@Test func preparingPresentationTakesPriorityOverAnExistingRow() {
  for status in [
    VideoAttachment.Status.pending,
    .uploading,
    .uploaded,
    .failed,
  ] {
    #expect(
      VideoAttachmentV3State.resolve(
        status: status,
        isPreparing: true,
        cameraAvailable: true
      ) == .preparing
    )
  }
}

@Test func replacementPreparationNeverShowsAttachedOrChoicesState() {
  let states = [
    VideoAttachmentV3State.resolve(
      status: .uploaded,
      isPreparing: true,
      cameraAvailable: true
    ),
    VideoAttachmentV3State.resolve(
      status: .uploaded,
      isPreparing: true,
      cameraAvailable: false
    ),
    VideoAttachmentV3State.resolve(
      status: nil,
      isPreparing: true,
      cameraAvailable: true
    ),
  ]

  #expect(states == [.preparing, .preparing, .preparing])
}

@MainActor
@Test func preparingControlsShowProgressWithoutActions() throws {
  let inspected = try VideoAttachmentV3Controls(
    state: .preparing,
    onCamera: {},
    onLibrary: {},
    onCancel: {},
    onRetry: {},
    onDelete: {}
  ).inspect()

  #expect(try inspected.find(text: "处理中…").string() == "处理中…")
  #expect(!inspected.findAll(ViewType.ProgressView.self).isEmpty)
  #expect(inspected.findAll(ViewType.Button.self).isEmpty)
}

#if os(macOS)
  import AppKit

  @MainActor
  @Test func failureActionsFitMinimumPhoneWidthInOneRow() {
    let controls = VideoAttachmentV3Controls(
      state: .failed, onCamera: {}, onLibrary: {}, onCancel: {}, onRetry: {}, onDelete: {}
    )
    .frame(width: 288)
    // 320pt screen minus the existing 16pt page insets on both sides.
    let size = NSHostingView(rootView: controls).fittingSize
    #expect(size.width == 288)
    #expect(size.height == 44)
  }
#endif
