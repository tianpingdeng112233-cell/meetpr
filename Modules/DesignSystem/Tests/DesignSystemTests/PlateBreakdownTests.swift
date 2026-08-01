import Testing

@testable import DesignSystem

@Suite("Plate breakdown")
struct PlateBreakdownTests {
  @Test("20kg is an empty bar")
  func emptyBar() {
    #expect(plateBreakdown(totalKg: 20, hasCollar: false).isEmpty)
    #expect(plateBreakdown(totalKg: 20, hasCollar: true).isEmpty)
  }

  @Test("Accessibility text matches empty, collar-only, and loaded branches")
  @MainActor
  func accessibilityText() {
    #expect(PlateVisual.accessibilityText([], showCollar: false) == "空杠 20kg")
    #expect(PlateVisual.accessibilityText([], showCollar: true) == "仅 2.5kg 赛扣")
    #expect(
      PlateVisual.accessibilityText([25, 25, 25], showCollar: true)
        == "25kg × 3 + 2.5kg 赛扣"
    )
    #expect(PlateVisual.accessibilityText([25, 2.5], showCollar: false) == "25kg × 1 · 2.5kg × 1")
  }

  @Test("175kg greedily loads three 25s and a 2.5 per side")
  func oneHundredSeventyFive() {
    #expect(weights(totalKg: 175, hasCollar: false) == [25, 25, 25, 2.5])
  }

  @Test("Collars subtract 2.5kg per side without changing plate rules")
  func collarSwitch() {
    #expect(weights(totalKg: 175, hasCollar: false) == [25, 25, 25, 2.5])
    #expect(weights(totalKg: 175, hasCollar: true) == [25, 25, 25])
  }

  @Test("20kg and 500kg boundaries are clamped")
  func boundaries() {
    #expect(weights(totalKg: 0, hasCollar: false).isEmpty)
    #expect(weights(totalKg: 20, hasCollar: false).isEmpty)
    #expect(
      weights(totalKg: 500, hasCollar: false)
        == [25, 25, 25, 25, 25, 25, 25, 25, 25, 15]
    )
    #expect(weights(totalKg: 800, hasCollar: false) == weights(totalKg: 500, hasCollar: false))
  }

  @Test("Every 0.25kg input uses valid descending denominations")
  func quarterKiloInputs() {
    let denominations = [25.0, 20, 15, 10, 5, 2.5, 1.25]

    for quarterStep in 80...2_000 {
      let totalKg = Double(quarterStep) / 4
      for hasCollar in [false, true] {
        let plates = plateBreakdown(totalKg: totalKg, hasCollar: hasCollar)
        let available =
          max(0, ((totalKg - 20) / 2) - (hasCollar ? 2.5 : 0))
        let loaded = plates.reduce(0) { $0 + $1.weightKg }

        #expect(plates.allSatisfy { denominations.contains($0.weightKg) })
        #expect(zip(plates, plates.dropFirst()).allSatisfy { $0.weightKg >= $1.weightKg })
        #expect(loaded <= available + 0.000_001)
        #expect(available - loaded < 1.25)
      }
    }

    #expect(weights(totalKg: 175.25, hasCollar: false) == [25, 25, 25, 2.5])
  }

  private func weights(totalKg: Double, hasCollar: Bool) -> [Double] {
    plateBreakdown(totalKg: totalKg, hasCollar: hasCollar).map(\.weightKg)
  }
}

@Suite("NumberPad snapping")
struct NumberPadSnappingTests {
  @Test("Weight snaps by quarter kilo within bounds")
  @MainActor
  func weightSnapping() {
    #expect(MeetPRNumberPad.snapped(19.8, field: .weight) == 20)
    #expect(MeetPRNumberPad.snapped(175.13, field: .weight) == 175.25)
    #expect(MeetPRNumberPad.snapped(500.2, field: .weight) == 500)
  }

  @Test("Accessory weight floor of 0 allows sub-20 loads")
  @MainActor
  func accessoryWeightFloor() {
    #expect(MeetPRNumberPad.snapped(12.5, field: .weight, minimumWeight: 0) == 12.5)
    #expect(MeetPRNumberPad.snapped(5.13, field: .weight, minimumWeight: 0) == 5.25)
    #expect(MeetPRNumberPad.snapped(0, field: .weight, minimumWeight: 0) == 0)
    #expect(MeetPRNumberPad.snapped(-3, field: .weight, minimumWeight: 0) == 0)
    #expect(MeetPRNumberPad.snapped(500.2, field: .weight, minimumWeight: 0) == 500)
  }

  @Test("Reps snap to whole values within bounds")
  @MainActor
  func repsSnapping() {
    #expect(MeetPRNumberPad.snapped(0, field: .reps) == 1)
    #expect(MeetPRNumberPad.snapped(7.6, field: .reps) == 8)
    #expect(MeetPRNumberPad.snapped(101, field: .reps) == 100)
  }
}
