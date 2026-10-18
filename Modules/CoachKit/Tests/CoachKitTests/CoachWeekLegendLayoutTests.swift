import Foundation
import Testing

@testable import CoachKit

@Suite("Coach week legend layout")
struct CoachWeekLegendLayoutTests {
  @Test("Groups fill the bar proportionally with only inter-group gaps")
  func proportionalFrames() {
    let layout = CoachWeekLegendLayout(weights: [2, 5, 1], spacing: 3)

    let frames = layout.frames(in: CGRect(x: 20, y: 10, width: 326, height: 8))

    #expect(
      frames == [
        CGRect(x: 20, y: 10, width: 80, height: 8),
        CGRect(x: 103, y: 10, width: 200, height: 8),
        CGRect(x: 306, y: 10, width: 40, height: 8),
      ])
  }

  @Test("A single group fills the entire width without a gap")
  func singleGroup() {
    let layout = CoachWeekLegendLayout(weights: [8], spacing: 3)
    let bounds = CGRect(x: 20, y: 10, width: 326, height: 8)

    #expect(layout.frames(in: bounds) == [bounds])
  }

  @Test("Zero rows produce no segments")
  func zeroRows() {
    let layout = CoachWeekLegendLayout(weights: [], spacing: 3)

    #expect(layout.frames(in: CGRect(x: 0, y: 0, width: 326, height: 8)).isEmpty)
  }

  @Test("A zero-width proposal produces finite, zero-width segments")
  func zeroWidth() {
    let layout = CoachWeekLegendLayout(weights: [2, 5, 1], spacing: 3)
    let bounds = CGRect(x: 0, y: 0, width: 0, height: 8)

    #expect(layout.frames(in: bounds) == [bounds, bounds, bounds])
  }
}
