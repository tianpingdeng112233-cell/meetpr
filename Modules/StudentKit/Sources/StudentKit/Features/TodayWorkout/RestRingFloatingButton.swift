import DesignSystem
import SwiftUI

/// Floating ring geometry: 16pt edge margin, 12pt gap to the header and the completion button.
enum RestRingMetrics {
  static let diameter: CGFloat = 76
  static let edgeInset: CGFloat = 16 + diameter / 2
  static let verticalInset: CGFloat = 12 + diameter / 2
}

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
  @Environment(\.colorScheme) private var colorScheme
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
      let inset = RestRingMetrics.verticalInset
      let lower = max(inset, headerBottom - origin + inset)
      // The completion dock includes space3 padding above its actual button.
      let buttonTop = dockTop.map { $0 + MeetPRSpacing.space3 } ?? (origin + proxy.size.height)
      let upper = max(
        lower, min(proxy.size.height, buttonTop - origin) - inset)
      let centerY = lower + (upper - lower) * min(1, max(0, verticalFraction))
      let centerX = left ? RestRingMetrics.edgeInset : proxy.size.width - RestRingMetrics.edgeInset
      let hintOnRight = centerX + translation.width < proxy.size.width / 2
      ZStack {
        if showsHint {
          HStack(spacing: 6) {
            if hintOnRight {
              Image(systemName: "arrow.left").accessibilityHidden(true)
            }
            Text(StudentStrings.localized(.restRingHint))
            if !hintOnRight {
              Image(systemName: "arrow.right").accessibilityHidden(true)
            }
          }
          .font(.system(size: 12))
          .foregroundStyle(
            colorScheme == .light ? Color.MeetPR.holdTrack : Color.MeetPR.textPrimary
          )
          .padding(10)
          .background(
            colorScheme == .light ? Color.MeetPR.gold200 : Color.MeetPR.surface2,
            in: .rect(cornerRadius: 10)
          )
          .overlay {
            if colorScheme == .light {
              RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.MeetPR.gold500, lineWidth: 1)
            }
          }
          .fixedSize()
          // Anchor to the ring's edge so translated text keeps an 8pt gap.
          .frame(
            width: RestRingMetrics.diameter, height: RestRingMetrics.diameter,
            alignment: hintOnRight ? .leading : .trailing
          )
          .offset(x: (RestRingMetrics.diameter + 8) * (hintOnRight ? 1 : -1))
          .position(x: centerX + translation.width, y: centerY + translation.height)
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
                  width: min(
                    proxy.size.width - RestRingMetrics.edgeInset,
                    max(RestRingMetrics.edgeInset, centerX + value.translation.width))
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
        RestRingProgress(remaining: remaining, total: total, width: 5)
        Text(RestRingTime.text(remaining))
          .font(.system(size: 20, weight: .bold, design: .monospaced))
          .foregroundStyle(remaining <= 10 ? Color.MeetPR.gold500 : Color.MeetPR.textPrimary)
      } else if done {
        Circle().strokeBorder(Color.MeetPR.gold500, lineWidth: 5)
        Text(StudentStrings.localized(.restRingDone))
          .font(.system(size: 15, weight: .bold))
          .multilineTextAlignment(.center)
          .foregroundStyle(Color.MeetPR.textPrimary)
      } else {
        Circle().strokeBorder(Color.MeetPR.gold500, lineWidth: 1.5)
        VStack(spacing: 3) {
          Image(systemName: "timer").font(.system(size: 24)).foregroundStyle(Color.MeetPR.gold500)
          Text(RestRingTime.text(remaining))
            .font(.system(size: 14, weight: .bold, design: .monospaced))
            .foregroundStyle(Color.MeetPR.textPrimary)
        }
      }
    }
    .frame(width: RestRingMetrics.diameter, height: RestRingMetrics.diameter)
    .contentShape(.circle)
  }
}

struct RestRingHeaderBottomKey: PreferenceKey {
  static let defaultValue: CGFloat = 0
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    value = max(value, nextValue())
  }
}
