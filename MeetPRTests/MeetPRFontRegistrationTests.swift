import Testing
import UIKit

@Suite("MeetPR bundled fonts")
struct MeetPRFontRegistrationTests {
  @Test("display, mono, and body fonts register in the app test host")
  func bundledFontsRegister() {
    #expect(UIFont(name: "ArchivoRoman-ExtraBold", size: 16) != nil)
    #expect(UIFont(name: "ArchivoRoman-Black", size: 16) != nil)
    #expect(UIFont(name: "IBMPlexMono-Regular", size: 16) != nil)
    #expect(UIFont(name: "IBMPlexMono-Medium", size: 16) != nil)
    #expect(UIFont(name: "IBMPlexMono-SemiBold", size: 16) != nil)
    #expect(UIFont(name: "IBMPlexMono-Bold", size: 16) != nil)
    #expect(UIFont(name: "IBMPlexSans-Regular", size: 16) != nil)
    #expect(UIFont(name: "IBMPlexSans-Medium", size: 16) != nil)
    #expect(UIFont(name: "IBMPlexSans-SemiBold", size: 16) != nil)
    #expect(UIFont(name: "IBMPlexSans-Bold", size: 16) != nil)
  }
}
