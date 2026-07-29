import Testing

@testable import StudentKit

/// The collar (赛扣) toggle shipped in 1.0(10) (#256) without coverage; these
/// lock in the v3 default-off contract, on/off arithmetic, sub-minimum guards,
/// and exact breakdown copy.
@MainActor
@Suite struct SetEntryPlateMathTests {
  @Test func setEntryAlwaysStartsWithCollarOff() {
    #expect(SetEntryPlateMath.defaultCollarOn == false)
  }

  @Test func perSideDropsCollarOnlyWhenOn() {
    #expect(SetEntryPlateMath.perSide(total: 120, collarOn: false) == 50)
    #expect(SetEntryPlateMath.perSide(total: 120, collarOn: true) == 47.5)
  }

  @Test func bareBarWithoutCollarUsesExactEmptyBarCopy() {
    #expect(SetEntryPlateMath.breakdownLine(total: 20, collarOn: false) == "空杠 20kg")
  }

  @Test func collarOnlyLoadReadsAsCollarOnly() {
    // `seBreakdown` is driven by the collar toggle: with no plate groups, the
    // exact v3 branch is collar-only even before the total is physically loadable.
    #expect(SetEntryPlateMath.breakdownLine(total: 20, collarOn: true) == "仅 2.5kg 赛扣")
    #expect(SetEntryPlateMath.breakdownLine(total: 22.5, collarOn: true) == "仅 2.5kg 赛扣")
    #expect(SetEntryPlateMath.breakdownLine(total: 25, collarOn: true) == "仅 2.5kg 赛扣")
    #expect(SetEntryPlateMath.plates(total: 25, collarOn: true).isEmpty)
  }

  @Test func groupedPlateCopyAndCollarSuffixAreExact() {
    #expect(SetEntryPlateMath.breakdownLine(total: 175, collarOn: false) == "25kg × 3 · 2.5kg × 1")
    #expect(SetEntryPlateMath.breakdownLine(total: 175, collarOn: true) == "25kg × 3 + 2.5kg 赛扣")
  }

  @Test func platesMatchGreedyLoadForPerSide() {
    // 170kg with collars → 72.5 per side (the design reference load).
    #expect(SetEntryPlateMath.plates(total: 170, collarOn: true) == [25, 25, 20, 2.5])
    #expect(SetEntryPlateMath.plates(total: 170, collarOn: false) == [25, 25, 25])
  }

}
