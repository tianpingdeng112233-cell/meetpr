import DesignSystem
import Foundation
import SwiftUI

/// Eleven-stop v3 RPE selector. Tap and horizontal scrub both write through the
/// same binding; vertical movement remains available to the enclosing scroll.
///
/// A cell is only ~30pt wide on a 393pt phone — under the 44pt touch minimum —
/// so scrubbing precision rests on three things (David 2026-07-29, after
/// "老是选错"): the finger never loses sight of the active stop (the bubble
/// tracks it above the strip), lifting off never re-reads the touch point, and
/// a gesture that turns out to be a scroll can never write a value.
@available(iOS 17.0, macOS 14.0, *)
struct SetEntryRPEScale: View {
  @Binding var value: Double
  let placeholder: String?
  @State private var bubbleWidth: CGFloat = 0
  /// What this gesture turned out to mean. Written and read only by
  /// `onChanged`/`onEnded` — one chain, in the order SwiftUI defines for a
  /// single gesture. Nothing else touches it, so the release decision can never
  /// race anything.
  @State private var scrubIntent = SetEntryRPE.ScrubIntent.idle
  /// Start point of the gesture `scrubIntent` describes. A cancelled gesture
  /// skips `onEnded` and leaves the intent behind; the next gesture notices the
  /// start point moved and rearms itself, so no cleanup has to happen outside
  /// this one chain.
  @State private var activeStart: CGPoint?
  /// Display only, never consulted when writing: `@GestureState` is restored on
  /// both endings, so a cancelled scrub drops the bubble immediately instead of
  /// leaving it stranded until the next touch.
  @GestureState private var isTouchDown = false
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  init(value: Binding<Double>, placeholder: String? = nil) {
    self._value = value
    self.placeholder = placeholder
  }

  /// There is no previewed-vs-committed split: a scrub writes the binding live,
  /// so what the student sees *is* what is stored. Releasing changes nothing,
  /// which is exactly what keeps lift-off drift from moving the value.
  private var activeValue: Double {
    SetEntryRPE.snap(value)
  }

  private var isScrubbing: Bool {
    isTouchDown && scrubIntent == .scrub
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
    .accessibilityValue(placeholder ?? SetEntryRPE.text(value))
    .accessibilityHint(StudentStrings.localized(.setEntryRpescale001))
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
      Text(placeholder == nil ? SetEntryRPE.text(activeValue) : "—")
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size32, weight: .bold))
        .foregroundStyle(
          placeholder == nil
            ? Color.MeetPR.textPrimary
            : Color.MeetPR.textGhost
        )
        .monospacedDigit()
        .contentTransition(.numericText())

      Spacer(minLength: MeetPRSpacing.space2)

      // The mockup always shows `SE_RIR[seIdx]` for the active value — even
      // mid-scrub there is no "release to confirm" copy. It only steps aside
      // while the bubble is up, which carries the same copy over the finger.
      Text(placeholder ?? SetEntryRPE.description(activeValue))
        .font(.MeetPR.body(size: MeetPRFontMetrics.size13, weight: .medium))
        .foregroundStyle(Color.MeetPR.textMuted)
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .opacity(isScrubbing ? 0 : 1)
    }
  }

  private var tickStrip: some View {
    GeometryReader { proxy in
      ZStack(alignment: .topLeading) {
        HStack(alignment: .bottom, spacing: MeetPRSpacing.point3) {
          ForEach(0..<SetEntryRPE.cellCount, id: \.self) { index in
            let tickValue = SetEntryRPE.minValue + Double(index) * SetEntryRPE.step
            tickBar(value: tickValue)
          }
        }
        .frame(width: proxy.size.width, height: 48, alignment: .bottom)
        .contentShape(.rect)
        // One gesture owns every write. The ticks used to be Buttons, which gave
        // a tap a second, unarbitrated path to the binding: a short drag could
        // fire both, and whichever ran last won.
        .simultaneousGesture(scrubGesture(width: proxy.size.width))

        if isScrubbing {
          scrubBubble
            .offset(x: bubbleOffset(stripWidth: proxy.size.width), y: -MeetPRSpacing.point36)
            // The strip's easeOut belongs to the bars. Inheriting it here made
            // the bubble chase the finger a frame-run behind on a fast scrub.
            .animation(nil, value: activeValue)
            .allowsHitTesting(false)
            .transition(.opacity)
        }
      }
    }
    .frame(height: 48)
    .animation(reduceMotion ? nil : MeetPRMotion.easeOut, value: activeValue)
    .animation(reduceMotion ? nil : MeetPRMotion.easeOut, value: isScrubbing)
    .sensoryFeedback(.selection, trigger: activeValue)
  }

  // MARK: - Scrub bubble
  //
  // No mockup source: the v3 design pack has no finger-tracking readout for this
  // control. David picked option B on 2026-07-29 and this shape is the
  // implementation's own — gold500 to read as "this is the selected stop",
  // reusing the header's two pieces of copy so nothing new is invented.

  private var scrubBubble: some View {
    HStack(spacing: MeetPRSpacing.point6) {
      Text(SetEntryRPE.text(activeValue))
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size18, weight: .bold))
        .monospacedDigit()

      Text(SetEntryRPE.description(activeValue))
        .font(.MeetPR.body(size: MeetPRFontMetrics.size12, weight: .medium))
    }
    .foregroundStyle(Color.MeetPR.inkOnGold)
    .lineLimit(1)
    .fixedSize()
    .padding(.horizontal, MeetPRSpacing.point10)
    .padding(.vertical, MeetPRSpacing.point6)
    .background(Capsule().fill(Color.MeetPR.gold500))
    .background(
      GeometryReader { bubble in
        Color.clear.preference(key: ScrubBubbleWidthKey.self, value: bubble.size.width)
      }
    )
    .onPreferenceChange(ScrubBubbleWidthKey.self) { bubbleWidth = $0 }
  }

  /// Centre the bubble over the active tick, then keep it inside the strip so a
  /// stop at either end still reads fully.
  private func bubbleOffset(stripWidth: CGFloat) -> CGFloat {
    let center = SetEntryRPE.centerX(
      ofIndex: SetEntryRPE.index(for: activeValue),
      width: stripWidth,
      spacing: MeetPRSpacing.point3
    )
    return min(max(0, center - bubbleWidth / 2), max(0, stripWidth - bubbleWidth))
  }

  /// Pure presentation. VoiceOver reaches the control through the card's own
  /// adjustable action — the card is `.accessibilityElement(children: .ignore)`,
  /// so per-tick labels were never surfaced anyway.
  private func tickBar(value tickValue: Double) -> some View {
    let isWhole = tickValue.truncatingRemainder(dividingBy: 1) == 0
    let isSelected = abs(tickValue - activeValue) < 0.01
    let labelIsLit = isSelected || (isWhole && abs(tickValue - activeValue) < 0.3)

    return VStack(spacing: MeetPRSpacing.point6) {
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

  private func scrubGesture(width: CGFloat) -> some Gesture {
    DragGesture(minimumDistance: 0)
      .updating($isTouchDown) { _, touching, _ in touching = true }
      .onChanged { gesture in
        // Rearm if this is a different gesture than the one the intent belongs
        // to — the cancellation path, handled inside the same chain that reads
        // the intent rather than by an outside observer that could race it.
        if activeStart != gesture.startLocation {
          activeStart = gesture.startLocation
          scrubIntent = .idle
        }
        // Lock the intent and act on it in the same callback: the frame that
        // first crosses the threshold is also the frame that starts writing,
        // so no movement can slip through unrecorded.
        scrubIntent = SetEntryRPE.lockedIntent(
          current: scrubIntent, translation: gesture.translation)
        guard scrubIntent == .scrub else { return }
        value = SetEntryRPE.value(
          atX: gesture.location.x, width: width, spacing: MeetPRSpacing.point3)
      }
      .onEnded { gesture in
        defer {
          scrubIntent = .idle
          activeStart = nil
        }
        // A scrub has already written every value the student saw, so release
        // deliberately does nothing — the points a finger drifts on lift-off
        // can't push it to the neighbouring stop. A scroll must never write.
        // Only a touch that stayed put is a tap. This asks the locked intent
        // rather than the final translation, so a scroll that wanders back to
        // where it started is still a scroll.
        guard SetEntryRPE.commitsOnRelease(intent: scrubIntent) else { return }
        value = SetEntryRPE.value(
          atX: gesture.location.x, width: width, spacing: MeetPRSpacing.point3)
      }
  }

  private func barColor(value tickValue: Double, selected: Bool) -> Color {
    if selected {
      return Color.MeetPR.gold500
    }
    return SetEntryRPE.isLit(tickValue, selectedValue: activeValue)
      ? Self.litBar
      : Self.unlitBar
  }

  // Mockup literals are dark-theme values (#8A8A8E lit / #2C2C2E unlit);
  // David 2026-07-28: light theme inverts the weight so passed ticks stay
  // the stronger side there too.
  private static let litBar = Color(
    light: Color(red: 58 / 255, green: 58 / 255, blue: 64 / 255),
    dark: Color(red: 138 / 255, green: 138 / 255, blue: 142 / 255)
  )
  private static let unlitBar = Color(
    light: Color(red: 209 / 255, green: 211 / 255, blue: 214 / 255),
    dark: Color(red: 44 / 255, green: 44 / 255, blue: 46 / 255)
  )
  private static let inactiveLabel = Color(red: 82 / 255, green: 82 / 255, blue: 82 / 255)
}

/// Measured width of the scrub bubble, so it can be centred over the active
/// tick without overhanging the strip.
private struct ScrubBubbleWidthKey: PreferenceKey {
  static let defaultValue: CGFloat = 0

  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = nextValue()
  }
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
