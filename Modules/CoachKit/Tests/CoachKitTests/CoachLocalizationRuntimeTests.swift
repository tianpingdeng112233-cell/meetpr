import Foundation
import Testing

@testable import CoachKit

@Suite("CoachKit localization runtime")
struct CoachLocalizationRuntimeTests {
  @Test("native plural interpolation selects English variants at runtime")
  func nativePluralInterpolationSelectsEnglishVariants() throws {
    let english = Locale(identifier: "en")
    let fixture = try RuntimeLocalizationFixture.make()
    defer { try? FileManager.default.removeItem(at: fixture.url) }

    #expect(
      CoachBindStrings.waitingDays(1, locale: english, bundle: fixture.bundle)
        == "Waiting 1 day")
    #expect(
      CoachBindStrings.waitingDays(2, locale: english, bundle: fixture.bundle)
        == "Waiting 2 days")
    #expect(
      CoachLocalization.localized(
        "coach.inbox.pendingVideoPreview \(1) \("2 min ago")",
        locale: english,
        bundle: fixture.bundle)
        == "1 video awaiting feedback · 2 min ago")
    #expect(
      CoachLocalization.localized(
        "coach.inbox.pendingVideoPreview \(2) \("2 min ago")",
        locale: english,
        bundle: fixture.bundle)
        == "2 videos awaiting feedback · 2 min ago")
    #expect(
      CoachLocalization.localized(
        "coach.evaluation.duration.days \(1)", locale: english, bundle: fixture.bundle)
        == "1 day")
    #expect(
      CoachLocalization.localized(
        "coach.evaluation.duration.days \(2)", locale: english, bundle: fixture.bundle)
        == "2 days")
  }

  @Test("native interpolation preserves byte-exact Chinese rendering")
  func nativeInterpolationPreservesChineseRendering() throws {
    let chinese = Locale(identifier: "zh-Hans")
    let fixture = try RuntimeLocalizationFixture.make()
    defer { try? FileManager.default.removeItem(at: fixture.url) }

    #expect(
      CoachBindStrings.waitingDays(1, locale: chinese, bundle: fixture.chineseBundle)
        == "已等待 1 天")
    #expect(
      CoachBindStrings.waitingDays(2, locale: chinese, bundle: fixture.chineseBundle)
        == "已等待 2 天")
    #expect(
      CoachLocalization.localized(
        "coach.evaluation.remaining \(2) \(3)",
        locale: chinese,
        bundle: fixture.chineseBundle)
        == "评估期 · 还剩 2 天 3 小时")
    #expect(
      CoachLocalization.localized(
        "coach.planning.count.setsAndReps \(3) \("×") \(5)",
        locale: chinese,
        bundle: fixture.chineseBundle)
        == "3 组 × 5 次")
    #expect(
      CoachLocalization.localized(
        "coach.videoFeedback.repsValue \(8)",
        locale: chinese,
        bundle: fixture.chineseBundle)
        == "8 次")
  }
}

private struct RuntimeLocalizationFixture {
  let bundle: Bundle
  let chineseBundle: Bundle
  let url: URL

  static func make() throws -> RuntimeLocalizationFixture {
    let bundleURL = FileManager.default.temporaryDirectory
      .appending(path: "CoachLocalization-\(UUID().uuidString).bundle")
    let englishURL = bundleURL.appending(path: "en.lproj")
    let chineseURL = bundleURL.appending(path: "zh-Hans.lproj")
    try FileManager.default.createDirectory(at: englishURL, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: chineseURL, withIntermediateDirectories: true)

    try writeInfo(to: bundleURL)
    try writeEnglishStrings(to: englishURL)
    try writeChineseStrings(to: chineseURL)

    guard let bundle = Bundle(url: bundleURL),
      let chineseBundle = Bundle(url: chineseURL)
    else {
      throw CocoaError(.fileReadCorruptFile)
    }
    return RuntimeLocalizationFixture(
      bundle: bundle,
      chineseBundle: chineseBundle,
      url: bundleURL)
  }

  private static func writeInfo(to bundleURL: URL) throws {
    let info: [String: Any] = [
      "CFBundleDevelopmentRegion": "en",
      "CFBundleIdentifier": "com.meetpr.CoachLocalizationTests.\(UUID().uuidString)",
      "CFBundleLocalizations": ["en", "zh-Hans"],
      "CFBundleName": "CoachLocalizationTests",
      "CFBundlePackageType": "BNDL",
      "CFBundleShortVersionString": "1.0",
      "CFBundleVersion": "1",
    ]
    try propertyListData(info, format: .xml).write(to: bundleURL.appending(path: "Info.plist"))
  }

  private static func writeEnglishStrings(to englishURL: URL) throws {
    let english: [String: Any] = [
      "coach.bind.waiting.days %lld": plural(
        one: "Waiting %lld day",
        other: "Waiting %lld days"),
      "coach.evaluation.duration.days %lld": plural(
        one: "%lld day",
        other: "%lld days"),
      "coach.inbox.pendingVideoPreview %lld %@": plural(
        one: "%lld video awaiting feedback · %@",
        other: "%lld videos awaiting feedback · %@"),
    ]
    try propertyListData(english, format: .xml).write(
      to: englishURL.appending(path: "Localizable.stringsdict"))
  }

  private static func writeChineseStrings(to chineseURL: URL) throws {
    let chinese = [
      "coach.bind.waiting.days %lld": "已等待 %lld 天",
      "coach.evaluation.remaining %lld %lld": "评估期 · 还剩 %lld 天 %lld 小时",
      "coach.planning.count.setsAndReps %lld %@ %lld": "%lld 组 %@ %lld 次",
      "coach.videoFeedback.repsValue %lld": "%lld 次",
    ]
    try propertyListData(chinese, format: .binary).write(
      to: chineseURL.appending(path: "Localizable.strings"))
  }

  private static func plural(one: String, other: String) -> [String: Any] {
    [
      "NSStringLocalizedFormatKey": "%#@count@",
      "count": [
        "NSStringFormatSpecTypeKey": "NSStringPluralRuleType",
        "NSStringFormatValueTypeKey": "lld",
        "one": one,
        "other": other,
      ],
    ]
  }

  private static func propertyListData(
    _ value: Any,
    format: PropertyListSerialization.PropertyListFormat
  ) throws -> Data {
    try PropertyListSerialization.data(
      fromPropertyList: value,
      format: format,
      options: 0)
  }
}
