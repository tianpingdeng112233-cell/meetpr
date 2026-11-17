import DesignSystem
import SwiftUI

struct RestRingFloatingButton: View {
  let remaining: Int
  let total: Int
  let running: Bool
  let done: Bool
  let showsHint: Bool
  let headerBottom: CGFloat
  let dockTop: CGFloat?
  let onTap: () -> Void
  let onHold: () -> Void
  @AppStorage("meetpr.restRing.left") private var left = false
  @AppStorage("meetpr.restRing.verticalFraction") private var verticalFraction = 1.0
  @State private var translation: CGSize = .zero
  @State private var touchStarted: Date?
  @State private var holdTask: Task<Void, Never>?
  @State private var held = false
  @State private var dragged = false
  @State private var pressed = false

  var body: some View {
    GeometryReader { proxy in
      let origin = proxy.frame(in: .global).minY
      let lower = max(44, headerBottom - origin + 44)
      // The completion dock includes space3 padding above its actual button.
      let buttonTop = dockTop.map { $0 + MeetPRSpacing.space3 } ?? (origin + proxy.size.height)
      let upper = max(
        lower, min(proxy.size.height, buttonTop - origin) - 44)
      let centerY = lower + (upper - lower) * min(1, max(0, verticalFraction))
      let centerX = left ? 48.0 : proxy.size.width - 48
      ZStack {
        if showsHint {
          Text(StudentStrings.localized(.restRingHint))
            .font(.system(size: 12))
            .foregroundStyle(Color.MeetPR.textPrimary)
            .padding(10)
            .background(Color.MeetPR.surface2, in: .rect(cornerRadius: 10))
            .fixedSize()
            .position(x: left ? centerX + 120 : centerX - 120, y: centerY)
            .allowsHitTesting(false)
        }
        Button(action: onTap) {
          RestRingButtonFace(remaining: remaining, total: total, running: running, done: done)
        }
        .buttonStyle(.plain)
        .scaleEffect(pressed ? 1.06 : 1)
        .accessibilityLabel(StudentStrings.localized(running ? .restRingTimer : .restRingStart))
        .accessibilityValue(RestRingTime.text(remaining))
        .accessibilityAction(named: StudentStrings.localized(.restRingSettings), onHold)
        .accessibilityIdentifier("restRing.button")
        .position(x: centerX + translation.width, y: centerY + translation.height)
        .highPriorityGesture(
          DragGesture(minimumDistance: 0)
            .onChanged { value in
              if touchStarted == nil {
                touchStarted = .now
                pressed = true
                held = false
                dragged = false
                holdTask = Task { @MainActor in
                  try? await Task.sleep(for: .milliseconds(500))
                  guard !Task.isCancelled, !dragged else { return }
                  held = true
                  pressed = false
                  onHold()
                }
              }
              if hypot(value.translation.width, value.translation.height) > 8 {
                dragged = true
                pressed = false
                holdTask?.cancel()
              }
              if dragged {
                translation = CGSize(
                  width: min(proxy.size.width - 48, max(48, centerX + value.translation.width))
                    - centerX,
                  height: min(upper, max(lower, centerY + value.translation.height)) - centerY)
              }
            }
            .onEnded { value in
              holdTask?.cancel()
              if dragged {
                left = centerX + value.translation.width < proxy.size.width / 2
                if upper > lower {
                  verticalFraction = min(
                    1, max(0, (centerY + translation.height - lower) / (upper - lower)))
                }
              } else if !held, let touchStarted, Date().timeIntervalSince(touchStarted) < 0.25 {
                onTap()
              }
              resetTouch()
            }
        )
      }
    }
    .onDisappear { resetTouch() }
  }

  private func resetTouch() {
    holdTask?.cancel()
    holdTask = nil
    touchStarted = nil
    pressed = false
    translation = .zero
  }
}

private struct RestRingButtonFace: View {
  let remaining: Int
  let total: Int
  let running: Bool
  let done: Bool

  var body: some View {
    ZStack {
      Circle().fill(Color.MeetPR.surface3)
      if running {
        RestRingProgress(remaining: remaining, total: total, width: 4)
        Text(RestRingTime.text(remaining))
          .font(.system(size: 17, weight: .bold, design: .monospaced))
          .foregroundStyle(remaining <= 10 ? Color.MeetPR.gold500 : Color.MeetPR.textPrimary)
      } else if done {
        Circle().strokeBorder(Color.MeetPR.gold500, lineWidth: 4)
        Text(StudentStrings.localized(.restRingDone))
          .font(.system(size: 13, weight: .bold))
          .multilineTextAlignment(.center)
          .foregroundStyle(Color.MeetPR.textPrimary)
      } else {
        Circle().strokeBorder(Color.MeetPR.gold500, lineWidth: 1.5)
        VStack(spacing: 3) {
          Image(systemName: "timer").font(.system(size: 20)).foregroundStyle(Color.MeetPR.gold500)
          Text(RestRingTime.text(remaining))
            .font(.system(size: 12, weight: .bold, design: .monospaced))
            .foregroundStyle(Color.MeetPR.textPrimary)
        }
      }
    }
    .frame(width: 64, height: 64)
    .contentShape(.circle)
  }
}

struct RestRingHeaderBottomKey: PreferenceKey {
  static let defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = max(value, nextValue())
  }
}
