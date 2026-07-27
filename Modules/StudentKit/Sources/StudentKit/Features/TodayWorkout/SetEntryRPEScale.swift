import DesignSystem
import Foundation
import SwiftUI

/// Pure RPE scale contract from `SE_RIR` and `seTicks`.
enum SetEntryRPE {
  static let minValue = 5.0
  static let maxValue = 10.0
  static let step = 0.5
  static let cellCount = 11

  static let descriptions = [
    "还能多做 5 次",
    "还能多做 4-5 次",
    "还能多做 4 次",
    "还能多做 3-4 次",
    "还能多做 3 次",
    "还能多做 2-3 次",
    "还能多做 2 次",
    "还能多做 1-2 次",
    "还能多做 1 次",
    "或许还能多做 1 次",
    "力竭，无保留",
  ]

  static func snap(_ value: Double) -> Double {
    min(maxValue, max(minValue, (value * 2).rounded() / 2))
  }

  static func value(atX x: Double, width: Double) -> Double {
    guard width > 0 else { return minValue }
    let raw = Int((x / width * Double(cellCount)).rounded(.down))
    let index = min(cellCount - 1, max(0, raw))
    return minValue + Double(index) * step
  }

  static func description(_ value: Double) -> String {
    descriptions[Int(((snap(value) - minValue) * 2).rounded())]
  }

  static func text(_ value: Double) -> String {
    snap(value).formatted(.number.precision(.fractionLength(1)))
  }

  static func barHeight(for value: Double, selectedValue: Double) -> CGFloat {
    if abs(value - snap(selectedValue)) < 0.01 {
      return 32
    }
    return value.truncatingRemainder(dividingBy: 1) == 0 ? 22 : 13
  }

  static func isLit(_ value: Double, selectedValue: Double) -> Bool {
    value <= snap(selectedValue) + 0.01
  }
}

/// Eleven-stop v3 RPE selector. Tap and horizontal scrub both write through the
/// same binding; vertical movement remains available to the enclosing scroll.
@available(iOS 17.0, macOS 14.0, *)
struct SetEntryRPEScale: View {
  @Binding var value: Double
  @State private var previewValue: Double?
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  private var activeValue: Double {
    SetEntryRPE.snap(previewValue ?? value)
  }

  var body: some View {
    VStack(spacing: MeetPRSpacing.point10) {
      header
      tickStrip
    }
    .padding(.horizontal, MeetPRSpacing.point14)
    .padding(.vertical, MeetPRSpacing.point13)
    .background(Color.MeetPR.surfaceCard)
    .clipShape(.rect(cornerRadius: MeetPRRadius.card))
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("RPE")
    .accessibilityValue(SetEntryRPE.text(value))
    .accessibilityHint("上下滑动，每次 0.5")
    .accessibilityAdjustableAction { direction in
      switch direction {
      case .increment:
        value = min(SetEntryRPE.maxValue, SetEntryRPE.snap(value) + SetEntryRPE.step)
      case .decrement:
        value = max(SetEntryRPE.minValue, SetEntryRPE.snap(value) - SetEntryRPE.step)
      @unknown default:
        break
      }
    }
  }

  private var header: some View {
    HStack(alignment: .lastTextBaseline, spacing: MeetPRSpacing.space2) {
      Text(SetEntryRPE.text(activeValue))
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size32, weight: .bold))
        .foregroundStyle(Color.MeetPR.textPrimary)
        .monospacedDigit()
        .contentTransition(.numericText())

      Spacer(minLength: MeetPRSpacing.space2)

      // The mockup always shows `SE_RIR[seIdx]` for the active value — even
      // mid-scrub there is no "release to confirm" copy.
      Text(SetEntryRPE.description(activeValue))
        .font(.MeetPR.body(size: MeetPRFontMetrics.size13, weight: .medium))
        .foregroundStyle(Color.MeetPR.textMuted)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
  }

  private var tickStrip: some View {
    GeometryReader { proxy in
      HStack(alignment: .bottom, spacing: MeetPRSpacing.point3) {
        ForEach(0..<SetEntryRPE.cellCount, id: \.self) { index in
          let tickValue = SetEntryRPE.minValue + Double(index) * SetEntryRPE.step
          tickButton(value: tickValue)
        }
      }
      .frame(width: proxy.size.width, height: 48, alignment: .bottom)
      .contentShape(.rect)
      .simultaneousGesture(scrubGesture(width: proxy.size.width))
    }
    .frame(height: 48)
    .animation(reduceMotion ? nil : MeetPRMotion.easeOut, value: activeValue)
    .sensoryFeedback(.selection, trigger: activeValue)
  }

  private func tickButton(value tickValue: Double) -> some View {
    let isWhole = tickValue.truncatingRemainder(dividingBy: 1) == 0
    let isSelected = abs(tickValue - activeValue) < 0.01
    let labelIsLit = isSelected || (isWhole && abs(tickValue - activeValue) < 0.3)

    return Button {
      value = tickValue
    } label: {
      VStack(spacing: MeetPRSpacing.point6) {
        ZStack(alignment: .bottom) {
          Color.clear.frame(height: 32)
          RoundedRectangle(cornerRadius: MeetPRSpacing.point3)
            .fill(barColor(value: tickValue, selected: isSelected))
            .frame(
              width: MeetPRSpacing.point6,
              height: SetEntryRPE.barHeight(for: tickValue, selectedValue: activeValue)
            )
        }

        Text(isWhole ? Int(tickValue).formatted() : "")
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size12, weight: .semibold))
          .foregroundStyle(labelIsLit ? Color.MeetPR.textPrimary : Self.inactiveLabel)
          .frame(height: MeetPRSpacing.point14)
      }
      .frame(maxWidth: .infinity)
    }
    .buttonStyle(.plain)
    .accessibilityLabel("RPE \(SetEntryRPE.text(tickValue))")
  }

  private func scrubGesture(width: CGFloat) -> some Gesture {
    DragGesture(minimumDistance: 0)
      .onChanged { gesture in
        guard isHorizontal(gesture) else {
          previewValue = nil
          return
        }
        previewValue = SetEntryRPE.value(atX: gesture.location.x, width: width)
      }
      .onEnded { gesture in
        defer { previewValue = nil }
        guard isHorizontal(gesture) else { return }
        value = SetEntryRPE.value(atX: gesture.location.x, width: width)
      }
  }

  private func isHorizontal(_ gesture: DragGesture.Value) -> Bool {
    abs(gesture.translation.width) >= abs(gesture.translation.height)
  }

  private func barColor(value tickValue: Double, selected: Bool) -> Color {
    if selected {
      return Color.MeetPR.gold500
    }
    return SetEntryRPE.isLit(tickValue, selectedValue: activeValue)
      ? Self.litBar
      : Self.unlitBar
  }

  private static let litBar = Color(red: 138 / 255, green: 138 / 255, blue: 142 / 255)
  private static let unlitBar = Color(red: 44 / 255, green: 44 / 255, blue: 46 / 255)
  private static let inactiveLabel = Color(red: 82 / 255, green: 82 / 255, blue: 82 / 255)
}

#Preview("RPE · Every Stop · Dark") {
  ScrollView {
    VStack(spacing: MeetPRSpacing.space3) {
      ForEach(0..<SetEntryRPE.cellCount, id: \.self) { index in
        SetEntryRPEPreviewRow(value: SetEntryRPE.minValue + Double(index) * SetEntryRPE.step)
      }
    }
    .padding()
  }
  .background(Color.MeetPR.bgBase)
  .preferredColorScheme(.dark)
}

#Preview("RPE · Every Stop · Light") {
  ScrollView {
    VStack(spacing: MeetPRSpacing.space3) {
      ForEach(0..<SetEntryRPE.cellCount, id: \.self) { index in
        SetEntryRPEPreviewRow(value: SetEntryRPE.minValue + Double(index) * SetEntryRPE.step)
      }
    }
    .padding()
  }
  .background(Color.MeetPR.bgBase)
  .preferredColorScheme(.light)
}

@available(iOS 17.0, macOS 14.0, *)
private struct SetEntryRPEPreviewRow: View {
  @State private var value: Double

  init(value: Double) {
    _value = State(initialValue: value)
  }

  var body: some View {
    SetEntryRPEScale(value: $value)
  }
}
