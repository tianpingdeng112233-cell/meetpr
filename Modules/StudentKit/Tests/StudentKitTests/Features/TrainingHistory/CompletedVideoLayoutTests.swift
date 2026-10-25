#if os(macOS)
  import AppKit
  import CoreModels
  import DesignSystem
  import SwiftUI
  import Testing
  import ViewInspector

  @testable import StudentKit

  @MainActor
  struct CompletedVideoLayoutTests {
    @Test func playbackAndUploadUseEighteenPointsAndKeepTheOriginalTextRowHeight() throws {
      let reference = size(Text("100 kg × 5").font(.MeetPR.mono(size: 13)))
      let playback = CompletedSetVideoButton(video: .remote(UUID()), upload: nil, number: 1) { _ in
      }
      #expect(size(playback.font(.MeetPR.mono(size: 13))).height == reference.height)
      #expect(size(playback).width == 18)
      let playbackImage = try playback.inspect().find(ViewType.Image.self)
      #expect(try playbackImage.font() == Font.MeetPR.system(size: 18, weight: .light))
      #expect(try playbackImage.fixedFrame().width == 44)
      #expect(try playbackImage.fixedFrame().height == 44)
      for status in [VideoAttachment.Status.pending, .uploading, .failed] {
        let upload = VideoAttachment(
          id: UUID(), setLogID: UUID(), studentID: UUID(), status: status,
          contentType: "video/mp4", durationSeconds: 8, sizeBytes: 100,
          localFileName: "clip.mp4", recordedAt: .now)
        let indicator = CompletedSetVideoButton(video: nil, upload: upload, number: 1) { _ in }
        #expect(size(indicator.font(.MeetPR.mono(size: 13))).height == reference.height)
        #expect(size(indicator).width == 18)
        #expect(try indicator.inspect().find(ViewType.Image.self).font() == Font.system(size: 18))
      }
    }

    @Test func historyReservationAddsOnlyTheIconAndEightPointGap() {
      let original = size(
        HistorySetRow(label: "1", result: "100 kg × 5", completed: true))
      let reserved = size(
        HistorySetRow(
          label: "1", result: "100 kg × 5", completed: true, reservesVideoSpace: true))
      #expect(reserved.height == original.height)
      #expect(abs(reserved.width - original.width - 26) < 0.01)
    }

    private func size(_ view: some View) -> CGSize {
      NSHostingView(rootView: view).fittingSize
    }
  }
#endif
