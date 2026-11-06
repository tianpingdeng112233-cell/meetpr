import CoreModels
import Foundation
import Testing

@testable import ChatUI

@Suite struct ChatVideoCoverPresentationTests {
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
