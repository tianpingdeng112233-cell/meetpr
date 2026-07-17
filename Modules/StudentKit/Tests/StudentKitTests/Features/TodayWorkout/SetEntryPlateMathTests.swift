import Foundation
import Testing

@testable import StudentKit

/// The collar (赛扣) toggle shipped in 1.0(10) (#256) without coverage; these
/// lock in the on/off arithmetic, the sub-minimum guards, and the per-student
/// preference-key partitioning (post-ship review-loop findings 2026-07-17).
@MainActor
@Suite struct SetEntryPlateMathTests {
  @Test func perSideDropsCollarOnlyWhenOn() {
    #expect(SetEntryPlateMath.perSide(total: 120, collarOn: false) == 50)
    #expect(SetEntryPlateMath.perSide(total: 120, collarOn: true) == 47.5)
  }

  @Test func bareBarAndBelowShowsEmptyBar() {
    #expect(SetEntryPlateMath.breakdownLine(total: 20, collarOn: false) == "空杠 20kg")
    #expect(SetEntryPlateMath.breakdownLine(total: 20, collarOn: true) == "空杠 20kg")
    // Collar on but the total can't cover bar + both collars: same guard.
    #expect(SetEntryPlateMath.breakdownLine(total: 22.5, collarOn: true) == "空杠 20kg")
    #expect(SetEntryPlateMath.plates(total: 20, collarOn: true).isEmpty)
  }

  @Test func collarOnlyLoadReadsAsCollarOnly() {
    #expect(SetEntryPlateMath.breakdownLine(total: 25, collarOn: true) == "仅 2.5kg 赛扣")
    #expect(SetEntryPlateMath.plates(total: 25, collarOn: true).isEmpty)
  }

  @Test func collarSuffixFollowsToggle() {
    #expect(SetEntryPlateMath.breakdownLine(total: 120, collarOn: true).hasSuffix(" + 2.5kg 赛扣"))
    #expect(!SetEntryPlateMath.breakdownLine(total: 120, collarOn: false).contains("赛扣"))
  }

  @Test func platesMatchGreedyLoadForPerSide() {
    // 170kg with collars → 72.5 per side (the design reference load).
    #expect(SetEntryPlateMath.plates(total: 170, collarOn: true) == [25, 25, 20, 2.5])
    #expect(SetEntryPlateMath.plates(total: 170, collarOn: false) == [25, 25, 25])
  }

  @Test func collarKeyIsPartitionedPerStudent() {
    let first = UUID()
    let second = UUID()
    #expect(
      SetEntryPlateMath.collarDefaultsKey(for: first)
        != SetEntryPlateMath.collarDefaultsKey(for: second))
    #expect(
      SetEntryPlateMath.collarDefaultsKey(for: first)
        == SetEntryPlateMath.collarDefaultsKey(for: first))
    #expect(SetEntryPlateMath.collarDefaultsKey(for: nil) == "setEntry.collarOn.shared")
  }
}
