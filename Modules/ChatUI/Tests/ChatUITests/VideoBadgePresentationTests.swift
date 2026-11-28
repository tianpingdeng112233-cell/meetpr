import CoreGraphics
import SwiftUI
import Testing

@testable import ChatUI

#if canImport(UIKit)
  import UIKit
#endif

@Suite("Video training badge")
struct VideoBadgePresentationTests {
  #if canImport(UIKit)
    @Test("badge bundle contains the final wordmark at its artwork ratio")
    func wordmarkResource() throws {
      let image = try #require(UIImage(named: "MeetPRWordmark", in: .module, compatibleWith: nil))
      #expect(abs(image.size.width / image.size.height - 2443.0 / 605) < 0.001)
    }
  #endif

  @Test("replay includes the supplied ordinal and export omits it")
  func presentationModes() {
    let badge = VideoBadgeInfo(
      exerciseName: "相扑硬拉", weightKg: 180, reps: 5, rpe: 8.5, setOrdinal: 3)
    let replay = VideoBadgePresentation(info: badge, mode: .replay)
    #expect(replay.setOrdinal == 3)
    #expect(replay.exerciseName == "相扑硬拉")
    #expect(replay.weightText == "180")
    #expect(replay.reps == 5)
    #expect(replay.rpeText == "8.5")
    #expect(VideoBadgePresentation(info: badge, mode: .export).setOrdinal == nil)
  }

  @Test("optional metrics disappear and a set number alone cannot create a badge")
  func optionalContent() {
    let longName = String(repeating: "暂停低杠深蹲", count: 10)
    let load = VideoBadgePresentation(
      info: .init(exerciseName: longName, weightKg: 142.5, reps: 3), mode: .export)
    #expect(load.exerciseName == longName)
    #expect(load.weightText == "142.5")
    #expect(load.rpeText == nil)
    let bodyweight = VideoBadgePresentation(info: .init(reps: 8), mode: .export)
    #expect(bodyweight.weightText == nil)
    #expect(bodyweight.reps == 8)
    #expect(VideoBadgeInfo(rpe: 8).hasContent)
    #expect(!VideoBadgeInfo(exerciseName: "  ", weightKg: .infinity, setOrdinal: 1).hasContent)
  }

  @Test("long action names fit the card and only the visible prefix is rendered")
  @MainActor
  func longNameTruncation() throws {
    func render(_ name: String) throws -> CGImage {
      let card = VideoBadgeCard(
        presentation: .init(info: .init(exerciseName: name, reps: 5), mode: .export), scale: 1)
      return try #require(ImageRenderer(content: card).cgImage)
    }
    let prefix = String(repeating: "W", count: 60)
    let long = try render(prefix + "111")
    let suffixChanged = try render(prefix + "999")
    let prefixChanged = try render("iii" + prefix)
    #expect(long.width <= 452)
    #expect(long.height == (try render("Squat")).height)
    let pixels = try #require(long.dataProvider?.data as Data?)
    #expect(pixels == (suffixChanged.dataProvider?.data as Data?))
    #expect(pixels != (prefixChanged.dataProvider?.data as Data?))
  }

  @Test
  @MainActor
  func largerMarkKeepsCardHeight() throws {
    // The 27u mark overflows the 23u header row; the card stays 144u tall.
    let infos = [
      VideoBadgeInfo(exerciseName: "Squat", weightKg: 180, reps: 5, rpe: 8),
      VideoBadgeInfo(exerciseName: "Squat", weightKg: 180, reps: 5),
      VideoBadgeInfo(exerciseName: "Pull-up", reps: 8, rpe: 8),
    ]
    for info in infos {
      let card = VideoBadgeCard(presentation: .init(info: info, mode: .export), scale: 1)
      let image = try #require(ImageRenderer(content: card).cgImage)
      #expect(image.height == 144)
    }
  }

  @Test("export lower-left anchor scales with the fitted portrait artboard")
  func exportGeometry() {
    for (size, scale, anchor) in [
      (CGSize(width: 1080, height: 1920), 2.0, CGPoint(x: 88, y: 428)),
      (CGSize(width: 1920, height: 1080), 1.125, CGPoint(x: 49.5, y: 240.75)),
      (CGSize(width: 1080, height: 1440), 1.5, CGPoint(x: 66, y: 321)),
    ] {
      let layout = VideoBadgeLayout(size: size)
      #expect(Double(layout.scale) == scale)
      #expect(layout.exportInsets == anchor)
    }
  }

  @Test("portrait preferred transform swaps render dimensions and normalizes origin")
  @MainActor
  func portraitRenderGeometry() {
    let transform = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 180, ty: 0)
    let geometry = VideoBadgeExporter.renderGeometry(
      naturalSize: CGSize(width: 320, height: 180),
      preferredTransform: transform
    )
    let renderedBounds = CGRect(
      origin: .zero,
      size: CGSize(width: 320, height: 180)
    ).applying(geometry.transform)

    #expect(geometry.renderSize == CGSize(width: 180, height: 320))
    #expect(abs(renderedBounds.minX) < 0.001)
    #expect(abs(renderedBounds.minY) < 0.001)
  }
}
