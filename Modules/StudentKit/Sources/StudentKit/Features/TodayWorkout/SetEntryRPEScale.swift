import DesignSystem
import Foundation
import SwiftUI

/// Pure, testable RPE-scale math (bucket / snap / describe / display), kept out
/// of the view so the boundaries are unit-covered.
enum SetEntryRPE {
  static let minValue = 5.0
  static let maxValue = 10.0
  static let step = 0.5
  static let cellCount = 11  // idx 0…10 → 5.0…10.0

  /// Clamp to 5…10 and snap to the nearest 0.5.
  static func snap(_ value: Double) -> Double {
    min(maxValue, max(minValue, (value * 2).rounded() / 2))
  }

  /// Bucket a touch x (0…width) into one of the 11 half-point stops (mockup:
  /// floor of a full-width 11-way split), clamped to the ends.
  static func value(atX x: Double, width: Double) -> Double {
    guard width > 0 else { return minValue }
    let raw = Int((x / width * Double(cellCount)).rounded(.down))
    let index = min(cellCount - 1, max(0, raw))
    return minValue + Double(index) * step
  }

  /// Per-half-step RIR copy, index 0…10 → 5.0…10.0 (Tuchscherer–Zourdos scale:
  /// RPE n = 还能多做 10−n 次), phrased like the onboarding copy so the student
  /// reads what the exact score means, not a vague intensity band.
  private static let descriptions = [
    "还能多做 5 次",  // 5.0
    "还能多做 4-5 次",  // 5.5
    "还能多做 4 次",  // 6.0
    "还能多做 3-4 次",  // 6.5
    "还能多做 3 次",  // 7.0
    "还能多做 2-3 次",  // 7.5
    "还能多做 2 次",  // 8.0
    "还能多做 1-2 次",  // 8.5
    "还能多做 1 次",  // 9.0
    "或许还能多做 1 次",  // 9.5
    "力竭，无保留",  // 10.0
  ]

  /// RIR-based explanation of the value; `snap` clamps to 5…10 in 0.5 steps, so
  /// the index always lands inside `descriptions`.
  static func description(_ value: Double) -> String {
    descriptions[Int(((snap(value) - minValue) * 2).rounded())]
  }

  /// Display text, one fraction digit, locale-formatted (project FormatStyle).
  static func text(_ value: Double) -> String {
    value.formatted(.number.precision(.fractionLength(1)))
  }
}

/// RPE tick-scale selector for the set-entry sheet (design `SetEntryRPE`): a big
/// value + RIR explanation over an 11-tick strip (5.0…10.0 in 0.5 steps). Drag
/// horizontally (or tap) to preview; release to commit. While the finger is down
/// the word reads 松开确认 and the big number tracks the finger; on release the
/// word snaps to the RIR explanation of the committed value. A vertical drag is
/// treated as a scroll and left to the enclosing ScrollView.
///
/// Bar heights (40 selected / 26 whole / 16 half) and lit `#8A8A8E` / unlit
/// `#2C2C2E` are reproduced 1:1 from the reference.
@available(iOS 17.0, macOS 14.0, *)
struct SetEntryRPEScale: View {
  /// Committed RPE, clamped to 5…10 in 0.5 steps. Written on release / a11y step.
  @Binding var value: Double
  /// Finger-down preview value; `nil` when idle. Drives the live number + 松开确认.
  @State private var previewValue: Double?

  /// The value the strip currently reflects: the finger preview if dragging,
  /// otherwise the committed value.
  private var active: Double { previewValue ?? value }

  var body: some View {
    VStack(alignment: .leading, spacing: 14) {
      header
      strip
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(RoundedRectangle(cornerRadius: 16).fill(Color.MeetPR.surface2))
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("RPE")
    .accessibilityValue(SetEntryRPE.text(value))
    .accessibilityHint("上下滑动，每次 0.5")
    .accessibilityAdjustableAction { direction in
      switch direction {
      case .increment: value = min(SetEntryRPE.maxValue, SetEntryRPE.snap(value) + SetEntryRPE.step)
      case .decrement: value = max(SetEntryRPE.minValue, SetEntryRPE.snap(value) - SetEntryRPE.step)
      @unknown default: break
      }
    }
  }

  // MARK: - Header (value + intensity word)

  private var header: some View {
    HStack(alignment: .firstTextBaseline) {
      Text(SetEntryRPE.text(active))
        .font(.system(size: 40, weight: .heavy, design: .monospaced))
        .foregroundStyle(Color.MeetPR.fgPrimary)
        .monospacedDigit()
        .contentTransition(.numericText())
      Spacer(minLength: 8)
      Text(hint)
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(Color.MeetPR.fgTertiary)
    }
  }

  /// RIR explanation of the *committed* value; 松开确认 while a drag is in flight.
  private var hint: String {
    previewValue != nil ? "松开确认" : SetEntryRPE.description(value)
  }

  // MARK: - Tick strip

  private var strip: some View {
    GeometryReader { proxy in
      let width = proxy.size.width
      HStack(spacing: 3) {
        ForEach(0..<SetEntryRPE.cellCount, id: \.self) { index in
          cell(index: index)
        }
      }
      .frame(width: width, height: 60, alignment: .bottom)
      .contentShape(.rect)
      // simultaneousGesture (not gesture): a vertical drag still scrolls the
      // sheet; we only preview/commit when the horizontal intent dominates, so a
      // scroll that starts on the strip never mis-sets RPE.
      .simultaneousGesture(
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
      )
    }
    .frame(height: 60)
    .animation(.easeOut(duration: 0.2), value: active)
    .sensoryFeedback(.selection, trigger: active)
  }

  /// A tap (zero translation) or a horizontal-dominant drag counts as scrubbing;
  /// a vertical-dominant drag is a scroll and is ignored.
  private func isHorizontal(_ gesture: DragGesture.Value) -> Bool {
    abs(gesture.translation.width) >= abs(gesture.translation.height)
  }

  private func cell(index: Int) -> some View {
    let cellValue = SetEntryRPE.minValue + Double(index) * SetEntryRPE.step
    let whole = cellValue.truncatingRemainder(dividingBy: 1) == 0
    let selected = abs(cellValue - active) < 0.01
    let lit = cellValue <= active + 0.01
    let barHeight: CGFloat = selected ? 40 : whole ? 26 : 16
    let labelLit = selected || (whole && abs(cellValue - active) < 0.3)

    return VStack(spacing: 6) {
      ZStack(alignment: .bottom) {
        Color.clear.frame(height: 40)
        RoundedRectangle(cornerRadius: 3)
          .fill(selected ? Self.selectedBar : lit ? Self.litBar : Self.unlitBar)
          .frame(width: 6, height: barHeight)
      }
      Text(whole ? "\(Int(cellValue))" : "")
        .font(.system(size: 12, weight: .semibold, design: .monospaced))
        .foregroundStyle(labelLit ? Color.MeetPR.fgPrimary : Self.inactiveLabel)
        .frame(height: 14)
    }
    .frame(maxWidth: .infinity)
  }

  // MARK: - Bar / label colours (mockup dark values, light-mode fallbacks)

  private static let selectedBar = Color.MeetPR.fgPrimary
  private static let litBar = Color(light: rgb(168, 168, 172), dark: rgb(138, 138, 142))
  private static let unlitBar = Color(light: rgb(220, 220, 222), dark: rgb(44, 44, 46))
  private static let inactiveLabel = Color(light: rgb(168, 168, 168), dark: rgb(82, 82, 82))

  private static func rgb(_ red: Double, _ green: Double, _ blue: Double) -> Color {
    Color(red: red / 255, green: green / 255, blue: blue / 255)
  }
}

@available(iOS 17.0, macOS 14.0, *)
#Preview("RPE scale") {
  @Previewable @State var rpe = 8.0
  VStack {
    SetEntryRPEScale(value: $rpe)
    Text("value = " + SetEntryRPE.text(rpe)).foregroundStyle(.secondary)
  }
  .padding()
  .background(Color.MeetPR.bg)
  .preferredColorScheme(.dark)
}
