import CoreModels
import Foundation
import Testing

@testable import ChatUI

@Suite struct ChatVideoCoverPresentationTests {
  @Test func portraitCoverUsesImageRatioAndMinimumWidth() {
    #expect(
      ChatVideoCoverPresentation.frameSize(
        imageSize: CGSize(width: 600, height: 800), availableWidth: 320
      ) == CGSize(width: 180, height: 240))
    #expect(
      ChatVideoCoverPresentation.frameSize(
        imageSize: CGSize(width: 300, height: 800), availableWidth: 320
      ) == CGSize(width: 135, height: 240))
  }

  @Test func landscapeSquareAndMissingImagesKeepFullWidthCover() {
    for imageSize in [CGSize(width: 800, height: 600), CGSize(width: 600, height: 600), nil] {
      #expect(
        ChatVideoCoverPresentation.frameSize(
          imageSize: imageSize, availableWidth: 320
        ) == CGSize(width: 320, height: 150))
    }
  }

  @Test @MainActor func rememberedRatioIsAvailableBeforePosterReloadForSameVideo() {
    let memory = ChatVideoPosterDimensions()
    let videoID = UUID()
    #expect(memory.imageSize(for: videoID) == nil)
    memory.remember(CGSize(width: 600, height: 800), for: videoID)
    // A recreated card can synchronously size itself, without awaiting image loading.
    #expect(
      ChatVideoCoverPresentation.frameSize(
        imageSize: memory.imageSize(for: videoID), availableWidth: 320
      ) == CGSize(width: 180, height: 240))
    #expect(memory.imageSize(for: UUID()) == nil)
  }

  @Test func posterAndDurationAreOptionalIndependently() throws {
    let poster = try #require(URL(string: "https://example.com/poster.jpg"))
    for hasPoster in [false, true] {
      for hasDuration in [false, true] {
        let presentation = ChatVideoCoverPresentation(
          posterURL: hasPoster ? poster : nil, durationSeconds: hasDuration ? 65 : nil)
        #expect(presentation.posterURL == (hasPoster ? poster : nil))
        #expect(presentation.durationText == (hasDuration ? "1:05" : nil))
      }
    }
  }
}
