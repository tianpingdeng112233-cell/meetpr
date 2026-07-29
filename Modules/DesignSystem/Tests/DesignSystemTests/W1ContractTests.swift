import SwiftUI
import Testing

@testable import DesignSystem

@Suite("W1 v3 component contracts")
@MainActor
struct W1ContractTests {
  @Test("Product/presentation defaults are mapped without data defaults")
  func productDefaults() {
    let cta = GoldCTA {}
    #expect(cta.label == "开始训练")
    #expect(cta.sub == "蹲·推·拉")
    #expect(cta.variant == .primary)
    #expect(cta.icon == .play)

    let stat = StatTile(label: "体重", value: "83")
    #expect(stat.unit == "kg")
    #expect(stat.delta == "")
    if case .neutral = stat.accent {
      // The dc display default is intentionally adopted by the production API.
    } else {
      Issue.record("StatTile accent should default to .neutral")
    }

    let numberPad = MeetPRNumberPad(value: 175, onCommit: { _ in }, onCancel: {})
    #expect(numberPad.field == .weight)
  }

  @Test("StatTile accepts String, Double, and Int values")
  func statTileValueOverloads() {
    let stringTile = StatTile(label: "体重", value: "83")
    let doubleTile = StatTile(label: "体重", value: 83.25)
    let integerTile = StatTile(label: "体重", value: 83)

    #expect(stringTile.value == "83")
    #expect(doubleTile.value == "83.25")
    #expect(integerTile.value == "83")
  }

  @Test("SetRow and GoldCTA SVG metrics match dc source")
  func iconMetrics() {
    #expect(SetRowContract.indexColumnWidth == 22)
    #expect(SetRowContract.trailingColumnWidth == 64)
    #expect(SetRowContract.minimumRowHeight == 44)
    #expect(SetRowContract.horizontalPadding == 14)
    #expect(SetRowContract.iconSpacing == 11)
    #expect(SetRowContract.doneFrame == 16)
    #expect(SetRowContract.doneStroke == 2.5)
    #expect(SetRowContract.failedFrame == 15)
    #expect(SetRowContract.failedStroke == 2.6)
    #expect(SetRowContract.pendingFrame == 15)
    #expect(SetRowContract.pendingStroke == 2.4)
    #expect(SetRowContract.cameraFrame == 19)
    #expect(SetRowContract.cameraStroke == 2)

    #expect(GoldCTAContract.playFrame == 13)
    #expect(GoldCTAContract.primaryAndSecondaryLabelTracking == 0.16)
    #expect(GoldCTAContract.playLabelSpacing == 7)
    #expect(GoldCTAContract.logoutFrame == 17)
    #expect(GoldCTAContract.logoutStroke == 2)
    #expect(GoldCTAContract.chevronFrame == 13)
    #expect(GoldCTAContract.chevronStroke == 2.2)
    #expect(GoldCTAContract.chevronLabelSpacing == 3)
  }

  @Test("ExerciseCard collapsed source and canonical radius are locked")
  func exerciseCardMetrics() {
    #expect(ExerciseCardContract.collapsedWidthFraction == 0.92)
    #expect(ExerciseCardContract.radius == 16)
    #expect(ExerciseCardContract.expandedNameSize == 16)
    #expect(ExerciseCardContract.collapsedNameSize == 14)
    #expect(ExerciseCardContract.expandedBarMinimumHeight == 26)
    #expect(ExerciseCardContract.collapsedBarMinimumHeight == 18)
    #expect(ExerciseCardContract.collapsedCaretRotation == -90)
  }

  @Test("ExerciseCard summary includes failed-set suffix")
  func exerciseCardSummary() {
    let complete = [
      ExerciseSetRecord(
        index: 1,
        weight: 175,
        reps: 3,
        rpe: 8.5,
        status: .done,
        videoState: .uploaded
      ),
      ExerciseSetRecord(
        index: 2,
        weight: 175,
        reps: 3,
        rpe: 8.5,
        status: .failed,
        videoState: .failed
      ),
    ]

    #expect(
      ExerciseCard.summaryText(for: complete)
        == "2 组 · 175kg×3 @8.5 · 1 组未完成"
    )
  }

  @Test("ExerciseCard partial recorded sets still produce a receipt")
  func exerciseCardPartialSummary() {
    let partial = [
      ExerciseSetRecord(
        index: 1,
        weight: 175,
        reps: 3,
        rpe: 8.5,
        status: .done,
        videoState: .uploaded
      ),
      ExerciseSetRecord(
        index: 2,
        weight: 175,
        reps: 3,
        rpe: 8.5,
        status: .pending,
        videoState: .none
      ),
    ]

    #expect(ExerciseCard.summaryText(for: partial) == "1 组 · 175kg×3 @8.5")

    // Mockup `exSummary`: zero logged sets → empty string, never a 0/N counter.
    let untouched = [
      ExerciseSetRecord(
        index: 1,
        weight: 175,
        reps: 3,
        rpe: 8.5,
        status: .pending,
        videoState: .none
      )
    ]
    #expect(ExerciseCard.summaryText(for: untouched).isEmpty)
  }

  @Test("Frozen W0 entries retain legacy parameters")
  func legacyParameters() {
    #expect(SetReadOnlyCell.setLabel(forZeroBasedIndex: 1) == "#2")

    let brandButton = LegacyBrandPrimaryButton("开始") {}
    #expect(brandButton.subtitle == nil)
    #expect(brandButton.systemImage == nil)
    #expect(brandButton.isLoading == false)
    #expect(brandButton.isFullWidth == false)

    let plateLoadout = LegacyPlateLoadout(plates: [25, 5])
    #expect(plateLoadout.plates == [25, 5])
    #expect(plateLoadout.showCollar)
    #expect(PlateLoadout.load(perSide: 30) == [25, 5])

    #expect(StatusBadge(status: .ready).usesLegacyRendering)
    #expect(StatusBadge("已通知教练", tone: .success).usesLegacyRendering)
    #expect(!StatusBadge("已通知教练", tone: .success, dot: false).usesLegacyRendering)
    #expect(LegacyStatusBadgeContract.spacing == MeetPRSpacing.point6)
    #expect(LegacyStatusBadgeContract.fontSize == 11)
    #expect(LegacyStatusBadgeContract.tracking == 0.72)
    #expect(LegacyStatusBadgeContract.horizontalPadding == MeetPRSpacing.sm)
    #expect(LegacyStatusBadgeContract.verticalPadding == MeetPRSpacing.xs)
    #expect(LegacyStatusBadgeContract.borderOpacity == 0.32)
    #expect(LegacyStatusBadgeContract.borderWidth == 1)

    _ = SetReadOnlyCell(
      setIndex: 0,
      weightKg: nil,
      reps: nil,
      rpe: nil,
      isCompleted: false
    )
    _ = StatBlock(label: "Squat", value: "200", unit: "KG")
    _ = PlateLoadout(plates: [], showCollar: false)
    _ = BrandPrimaryButton(
      "Start",
      subtitle: nil,
      systemImage: nil,
      isLoading: true
    ) {}
    _ = SecondaryButton("Cancel", isDisabled: true, isFullWidth: true) {}
    _ = DangerButton("Delete", isDisabled: true, isFullWidth: true) {}
  }
}

@Suite("W1 PlateVisual source contracts")
struct W1PlateVisualContractTests {
  @Test("SE_SPEC and SE_DIM tables are complete")
  func sourceDimensionTables() {
    let expectedSpec: [Double: PlateSourceDimensions] = [
      25: .init(width: 12, height: 135),
      20: .init(width: 11, height: 135),
      15: .init(width: 11, height: 120),
      10: .init(width: 9, height: 98),
      5: .init(width: 9, height: 68),
      2.5: .init(width: 8, height: 57),
      1.25: .init(width: 7, height: 48),
    ]
    let expectedDimensions: [Double: PlateSourceDimensions] = [
      25: .init(width: 11, height: 135),
      20: .init(width: 8, height: 135),
      15: .init(width: 8, height: 120),
      10: .init(width: 8, height: 98),
      5: .init(width: 8, height: 68),
      2.5: .init(width: 6, height: 57),
      1.25: .init(width: 5, height: 48),
    ]

    #expect(PlateVisualContract.seSpecDimensions == expectedSpec)
    #expect(PlateVisualContract.seDimensions == expectedDimensions)
    #expect(Color.MeetPR.plate25Gradient.count == 8)
    #expect(Color.MeetPR.plate20Gradient.count == 8)
    #expect(Color.MeetPR.plate15Gradient.count == 8)
    #expect(Color.MeetPR.plate10Gradient.count == 8)
    #expect(Color.MeetPR.plate5Gradient.count == 8)
    #expect(Color.MeetPR.plate2Point5Gradient.count == 8)
    #expect(Color.MeetPR.plate1Point25Gradient.count == 8)
  }

  @Test("Plate and steel gradient locations match source")
  func gradientLocations() {
    #expect(PlateVisualContract.plateLocations == [0, 0.04, 0.15, 0.22, 0.46, 0.68, 0.90, 1])
    #expect(PlateVisualContract.shaftLocations == [0, 0.14, 0.34, 0.44, 0.60, 0.78, 1])
    #expect(PlateVisualContract.shoulderLocations == [0, 0.16, 0.40, 0.62, 0.80, 1])
    #expect(PlateVisualContract.sleeveLocations == [0, 0.15, 0.36, 0.46, 0.62, 0.80, 1])
    #expect(PlateVisualContract.collarBodyLocations == [0, 0.15, 0.33, 0.42, 0.58, 0.76, 1])
    #expect(PlateVisualContract.collarNutLocations == [0, 0.16, 0.36, 0.44, 0.58, 0.78, 1])
    #expect(PlateVisualContract.leverLocations == [0, 0.45, 1])
    #expect(PlateVisualContract.knobLocations == [0, 0.58, 1])
    #expect(PlateVisualContract.collarLeverLeft == 8)
    #expect(PlateVisualContract.collarLeverTop == 17)
  }
}
