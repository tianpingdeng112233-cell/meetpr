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
    .background(Color.MeetPR.bg)
  }

  private func header(_ loadout: PlateMathCalculator.Loadout) -> some View {
    HStack(alignment: .firstTextBaseline, spacing: MeetPRSpacing.sm) {
      Text("\(Self.kg(loadout.achievedKg)) kg")
        .font(Font.MeetPR.title2)
        .foregroundStyle(Color.MeetPR.fgPrimary)
      Text("杠 \(Self.kg(PlateMathCalculator.barWeightKg)) kg")
        .font(Font.MeetPR.footnote)
        .foregroundStyle(Color.MeetPR.fgSecondary)
    }
  }

  private func plateVisualization(_ loadout: PlateMathCalculator.Loadout) -> some View {
    HStack(alignment: .center, spacing: 3) {
      // Bar stub
      RoundedRectangle(cornerRadius: 2)
        .fill(Color.MeetPR.fgTertiary)
        .frame(width: 44, height: 8)

      ForEach(Array(loadout.platesPerSideKg.enumerated()), id: \.offset) { _, plate in
        plateView(plate)
      }

      if loadout.platesPerSideKg.isEmpty {
        Text("空杠")
          .font(Font.MeetPR.footnote)
          .foregroundStyle(Color.MeetPR.fgSecondary)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.vertical, MeetPRSpacing.sm)
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("每边配片：\(accessibilitySummary(loadout))")
  }

  private func plateView(_ denomination: Double) -> some View {
    let style = Self.plateStyle(denomination)
    return RoundedRectangle(cornerRadius: 3)
      .fill(style.color)
      .frame(width: 14, height: style.height)
      .overlay(
        RoundedRectangle(cornerRadius: 3)
          .strokeBorder(style.needsBorder ? Color.MeetPR.border : .clear, lineWidth: 1)
      )
  }

  private func plateList(_ loadout: PlateMathCalculator.Loadout) -> some View {
    let counts = loadout.platesPerSideKg.reduce(into: [Double: Int]()) { $0[$1, default: 0] += 1 }
    let parts = counts.keys.sorted(by: >).map { "\(Self.kg($0)) ×\(counts[$0] ?? 0)" }
    return Text(parts.isEmpty ? "每边：无（空杠）" : "每边：\(parts.joined(separator: " · "))")
      .font(Font.MeetPR.body)
      .foregroundStyle(Color.MeetPR.fgPrimary)
  }

  private func roundingNotice(_ loadout: PlateMathCalculator.Loadout) -> some View {
    Label(
      "目标 \(Self.kg(loadout.requestedKg)) kg → 实际 \(Self.kg(loadout.achievedKg)) kg（最小增量 2.5 kg）",
      systemImage: "info.circle"
    )
    .font(Font.MeetPR.footnote)
    .foregroundStyle(Color.MeetPR.amber)
  }

  private func accessibilitySummary(_ loadout: PlateMathCalculator.Loadout) -> String {
    loadout.platesPerSideKg.isEmpty
      ? "空杠"
      : loadout.platesPerSideKg.map { Self.kg($0) }.joined(separator: "，")
  }

  /// IPF standard plate colors; 5kg (white) and 2.5kg (black) get a border so
  /// they stay visible in both color schemes.
  private static func plateStyle(_ denomination: Double) -> (
    color: Color, height: CGFloat, needsBorder: Bool
  ) {
    switch denomination {
    case 25: (Color(red: 0.85, green: 0.15, blue: 0.15), 64, false)
    case 20: (Color(red: 0.15, green: 0.3, blue: 0.8), 60, false)
    case 15: (Color(red: 0.95, green: 0.8, blue: 0.1), 54, false)
    case 10: (Color(red: 0.15, green: 0.6, blue: 0.3), 46, false)
    case 5: (Color.white, 36, true)
    case 2.5: (Color.black, 28, true)
    default: (Color(white: 0.75), 22, false)  // 1.25 silver
    }
  }

  private static func kg(_ value: Double) -> String {
    value.truncatingRemainder(dividingBy: 1) == 0
      ? String(Int(value))
      : String(format: "%.2f", value).replacingOccurrences(of: ".50", with: ".5")
        .replacingOccurrences(of: ".00", with: "")
  }
}
