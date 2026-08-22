import CoreGraphics
import Testing

@testable import ChatUI

@Suite("Video training badge")
struct VideoBadgePresentationTests {
  @Test("optional fields disappear without placeholder content")
  func optionalFieldsDisappear() {
    let presentation = VideoBadgePresentation(
      info: VideoBadgeInfo(
        exerciseName: "  ",
        weightKg: .infinity,
        reps: nil,
        rpe: nil,
        setOrdinal: nil,
        coachName: "\n"
      )
    )

    #expect(presentation.exerciseName == nil)
    #expect(presentation.weightText == nil)
    #expect(presentation.reps == nil)
    #expect(presentation.rpeText == nil)
    #expect(presentation.setOrdinal == nil)
    #expect(presentation.coachName == nil)
    #expect(!presentation.hasLoad)
  }

  @Test("metrics use the app's zero-or-one-decimal display convention")
  func metricsFormatting() {
    let presentation = VideoBadgePresentation(
      info: VideoBadgeInfo(
        exerciseName: "传统硬拉",
        weightKg: 180,
        reps: 4,
        rpe: 8.5,
        setOrdinal: 3,
        coachName: "陈教练"
      )
    )

    #expect(presentation.exerciseName == "传统硬拉")
    #expect(presentation.weightText == "180")
    #expect(presentation.reps == 4)
    #expect(presentation.rpeText == "8.5")
    #expect(presentation.setOrdinal == 3)
    #expect(presentation.coachName == "陈教练")
    #expect(presentation.hasLoad)
  }

  @Test("component preserves display-ready set ordinals without incrementing")
  func preservesSetOrdinal() {
    let presentation = VideoBadgePresentation(
      info: VideoBadgeInfo(setOrdinal: 0)
    )

    #expect(presentation.setOrdinal == 0)
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
