import Testing

@testable import DesignSystem

@Suite("MeetPR typography tokens")
struct TypographyTests {
  @Test("font sizes match the complete mockup type scale")
  func fontSizesMatchMockupTypeScale() {
    let sizes = [
      MeetPRFontMetrics.size10, MeetPRFontMetrics.size11, MeetPRFontMetrics.size12,
      MeetPRFontMetrics.size13, MeetPRFontMetrics.size14, MeetPRFontMetrics.size15,
      MeetPRFontMetrics.size16, MeetPRFontMetrics.size17, MeetPRFontMetrics.size18,
      MeetPRFontMetrics.size19, MeetPRFontMetrics.size20, MeetPRFontMetrics.size21,
      MeetPRFontMetrics.size22, MeetPRFontMetrics.size24, MeetPRFontMetrics.size26,
      MeetPRFontMetrics.size27, MeetPRFontMetrics.size28, MeetPRFontMetrics.size30,
      MeetPRFontMetrics.size32, MeetPRFontMetrics.size34, MeetPRFontMetrics.size38,
      MeetPRFontMetrics.size46, MeetPRFontMetrics.size54,
    ]
    #expect(
      sizes == [
        10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 24, 26, 27, 28, 30,
        32, 34, 38, 46, 54,
      ])
  }

  @Test("PostScript names match inspected font assets")
  func postScriptNamesMatchInspectedFontAssets() {
    #expect(MeetPRFontFamily.archivoExtraBold == "ArchivoRoman-ExtraBold")
    #expect(MeetPRFontFamily.archivoBlack == "ArchivoRoman-Black")
    #expect(MeetPRFontFamily.ibmPlexMonoRegular == "IBMPlexMono-Regular")
    #expect(MeetPRFontFamily.ibmPlexMonoMedium == "IBMPlexMono-Medium")
    #expect(MeetPRFontFamily.ibmPlexMonoSemibold == "IBMPlexMono-SemiBold")
    #expect(MeetPRFontFamily.ibmPlexMonoBold == "IBMPlexMono-Bold")
    #expect(MeetPRFontFamily.ibmPlexSansRegular == "IBMPlexSans-Regular")
    #expect(MeetPRFontFamily.ibmPlexSansMedium == "IBMPlexSans-Medium")
    #expect(MeetPRFontFamily.ibmPlexSansSemibold == "IBMPlexSans-SemiBold")
    #expect(MeetPRFontFamily.ibmPlexSansBold == "IBMPlexSans-Bold")
  }

  @Test("missing custom font resolves to the system fallback branch")
  func missingCustomFontResolvesToSystemFallback() {
    #expect(
      MeetPRFontFamily.source(
        named: MeetPRFontFamily.archivoExtraBold,
        availability: { _ in false }
      ) == .system
    )
    #expect(
      MeetPRFontFamily.source(
        named: MeetPRFontFamily.archivoExtraBold,
        availability: { _ in true }
      ) == .custom(MeetPRFontFamily.archivoExtraBold)
    )
  }

  @Test("tracking values match the black-gold labels")
  func trackingValuesMatchBlackGoldLabels() {
    #expect(MeetPRFontMetrics.monoLabelTracking == 0.6)
    #expect(MeetPRFontMetrics.displayUnitTracking == 0.8)
  }
}
