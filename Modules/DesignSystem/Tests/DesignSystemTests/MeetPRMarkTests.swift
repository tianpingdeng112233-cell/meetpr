import SwiftUI
import Testing

@testable import DesignSystem

#if canImport(UIKit)
  import UIKit
#endif

@MainActor
struct MeetPRMarkTests {
  @Test func headerUsesFinalArtworkDimensions() {
    var size = CGSize.zero
    ImageRenderer(content: MeetPRMark.header).render { pointSize, _ in
      size = pointSize
    }
    #expect(size.height == 18)
    #expect(abs(size.width - 18 * 2443.0 / 605) < 0.001)
  }

  #if canImport(UIKit)
    @Test func artworkChangesWithAppearance() throws {
      func artwork(_ style: UIUserInterfaceStyle) throws -> Data {
        let traits = UITraitCollection(userInterfaceStyle: style)
        let image = try #require(UIImage(named: "MeetPRMark", in: .module, compatibleWith: traits))
        return try #require(image.pngData())
      }
      let light = try artwork(.light)
      let dark = try artwork(.dark)
      #expect(light != dark)
    }
  #endif
}
