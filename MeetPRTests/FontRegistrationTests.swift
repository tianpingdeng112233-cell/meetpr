import CoreText
import Testing
import UIKit

@Suite("Bundled font registration")
struct FontRegistrationTests {
  private static let expectedFontFiles = [
    "Archivo-VF.ttf",
    "IBMPlexMono-Bold.ttf",
    "IBMPlexMono-Medium.ttf",
    "IBMPlexMono-Regular.ttf",
    "IBMPlexMono-SemiBold.ttf",
    "IBMPlexSans-VF.ttf",
  ]

  @Test("Info.plist registers exactly the six handoff fonts")
  func infoPlistRegistersAllHandoffFonts() {
    let registeredFiles =
      Bundle.main.object(forInfoDictionaryKey: "UIAppFonts") as? [String]

    #expect(registeredFiles?.sorted() == Self.expectedFontFiles)
  }

  /// Every PostScript name Typography actually requests (MeetPRFontFamily),
  /// including the variable fonts' named instances.
  private static let typographyRequestedNames = [
    "ArchivoRoman-ExtraBold",
    "ArchivoRoman-Black",
    "IBMPlexMono-Regular",
    "IBMPlexMono-Medium",
    "IBMPlexMono-SemiBold",
    "IBMPlexMono-Bold",
    "IBMPlexSans-Regular",
    "IBMPlexSans-Medium",
    "IBMPlexSans-SemiBold",
    "IBMPlexSans-Bold",
  ]

  @Test("every Typography-requested face resolves through UIFont")
  func customFontsResolveThroughUIFont() {
    for name in Self.typographyRequestedNames {
      #expect(UIFont(name: name, size: 16) != nil, "\(name) is not resolvable")
    }
  }

  @Test("every bundled font file's PostScript name resolves through UIFont")
  func everyBundledFontFileResolves() throws {
    for file in Self.expectedFontFiles {
      let resource = String(file.dropLast(4))
      let url = try #require(
        Bundle.main.url(forResource: resource, withExtension: "ttf"),
        "\(file) missing from the app bundle"
      )
      let data = try Data(contentsOf: url)
      let descriptors =
        CTFontManagerCreateFontDescriptorsFromData(data as CFData) as? [CTFontDescriptor]
      let postScriptName = try #require(
        descriptors?.first.flatMap {
          CTFontDescriptorCopyAttribute($0, kCTFontNameAttribute) as? String
        },
        "\(file) has no readable PostScript name"
      )
      #expect(
        UIFont(name: postScriptName, size: 16) != nil,
        "\(postScriptName) from \(file) is not registered"
      )
    }
  }
}
