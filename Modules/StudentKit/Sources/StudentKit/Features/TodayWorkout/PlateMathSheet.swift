import CoreModels
import DesignSystem
import SwiftUI

/// Plate-loading bottom sheet (spec 030 §A2): per-side IPF-colored plate
/// stack + aggregated list + rounding notice. Plate colors are domain
/// constants (IPF standard), deliberately NOT Color.MeetPR tokens.
@available(iOS 17.0, macOS 14.0, *)
struct PlateMathSheet: View {
  let targetKg: Double

  private var loadout: PlateMathCalculator.Loadout? {
    PlateMathCalculator.loadout(forTargetKg: targetKg)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.md) {
      if let loadout {
        header(loadout)
        plateVisualization(loadout)
        plateList(loadout)
        if !loadout.isExact {
          roundingNotice(loadout)
        }
      } else {
        ContentUnavailableView(
          "低于空杠重量（20 kg）",
          systemImage: "scalemass",
          description: Text("目标重量低于标准杠自重，无法配片")
        )
      }
      Spacer(minLength: 0)
    }
    .padding(MeetPRSpacing.md)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.MeetPR.bgBase)
  }

  private func header(_ loadout: PlateMathCalculator.Loadout) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: MeetPRSpacing.sm) {
      Text("\(StudentFormatting.kilograms(loadout.achievedKg)) kg")
        .font(Font.MeetPR.title2)
        .foregroundStyle(Color.MeetPR.textPrimary)
      Text("杠 \(StudentFormatting.kilograms(PlateMathCalculator.barWeightKg)) kg")
        .font(Font.MeetPR.footnote)
        .foregroundStyle(Color.MeetPR.textSecondary)
    }
  }

  private func plateVisualization(_ loadout: PlateMathCalculator.Loadout) -> some View {
    HStack(alignment: .center, spacing: MeetPRSpacing.point3) {
      // Bar stub
      RoundedRectangle(cornerRadius: MeetPRRadius.point2)
        .fill(Color.MeetPR.textTertiary)
        .frame(width: 44, height: 8)

      ForEach(Array(loadout.platesPerSideKg.enumerated()), id: \.offset) { _, plate in
        plateView(plate)
      }

      if loadout.platesPerSideKg.isEmpty {
        Text("空杠")
          .font(Font.MeetPR.footnote)
          .foregroundStyle(Color.MeetPR.textSecondary)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.vertical, MeetPRSpacing.sm)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("每边配片：\(accessibilitySummary(loadout))")
  }

  private func plateView(_ denomination: Double) -> some View {
    let style = Self.plateStyle(denomination)
    return RoundedRectangle(cornerRadius: MeetPRRadius.point3)
      .fill(style.color)
      .frame(width: 14, height: style.height)
      .overlay(
        RoundedRectangle(cornerRadius: MeetPRRadius.point3)
          .strokeBorder(style.needsBorder ? Color.MeetPR.borderDefault : .clear, lineWidth: 1)
      )
  }

  private func plateList(_ loadout: PlateMathCalculator.Loadout) -> some View {
    let counts = loadout.platesPerSideKg.reduce(into: [Double: Int]()) { $0[$1, default: 0] += 1 }
    let parts = counts.keys.sorted(by: >).map { denomination in
      "\(Self.denominationText(denomination)) ×\(counts[denomination] ?? 0)"
    }
    return Text(parts.isEmpty ? "每边：无（空杠）" : "每边：\(parts.joined(separator: " · "))")
      .font(Font.MeetPR.body)
      .foregroundStyle(Color.MeetPR.textPrimary)
      // 多片组合排版不乱 (P2-10): 片数多时让文案纵向换行,别横向截断。
      .fixedSize(horizontal: false, vertical: true)
      .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func roundingNotice(_ loadout: PlateMathCalculator.Loadout) -> some View {
    let requested = StudentFormatting.kilograms(loadout.requestedKg)
    let achieved = StudentFormatting.kilograms(loadout.achievedKg)
    return Label(
      "目标 \(requested) kg → 实际 \(achieved) kg（最小增量 2.5 kg）",
      systemImage: "info.circle"
    )
    .font(Font.MeetPR.footnote)
    .foregroundStyle(Color.MeetPR.gold500)
  }

  private func accessibilitySummary(_ loadout: PlateMathCalculator.Loadout) -> String {
    loadout.platesPerSideKg.isEmpty
      ? "空杠"
      : loadout.platesPerSideKg.map { Self.denominationText($0) }.joined(separator: "，")
  }

  private struct PlateStyle {
    let color: Color
    let height: CGFloat
    let needsBorder: Bool
  }

  /// Plate denominations need two fraction digits (1.25); totals use the
  /// shared one-digit weight style.
  private static func denominationText(_ value: Double) -> String {
    value.formatted(.number.precision(.fractionLength(0...2)))
  }

  /// IPF standard plate colors; 5kg (white) and 2.5kg (black) get a border so
  /// they stay visible in both color schemes.
  private static func plateStyle(_ denomination: Double) -> PlateStyle {
    switch denomination {
    case 25:
      PlateStyle(color: Color.MeetPR.plate25, height: 64, needsBorder: false)
    case 20:
      PlateStyle(color: Color.MeetPR.plate20, height: 60, needsBorder: false)
    case 15:
      PlateStyle(color: Color.MeetPR.plate15, height: 54, needsBorder: false)
    case 10:
      PlateStyle(color: Color.MeetPR.plate10, height: 46, needsBorder: false)
    case 5: PlateStyle(color: .white, height: 36, needsBorder: true)
    case 2.5: PlateStyle(color: .black, height: 28, needsBorder: true)
    default: PlateStyle(color: Color(white: 0.75), height: 22, needsBorder: false)  // 1.25 silver
    }
  }
}
