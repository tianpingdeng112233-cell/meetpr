import Foundation
import Testing

@testable import ChatUI

@Test func chatImageDownsamplerRejectsInvalidImageData() {
  #expect(throws: ChatImageDownsamplingError.invalidImage) {
    try ChatImageDownsampler().downsampleJPEG(Data("not-an-image".utf8))
  }
}
