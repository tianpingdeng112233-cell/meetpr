import DesignSystem
import SwiftUI

#if canImport(UIKit)
  import UIKit
#endif

/// Inter-set rest countdown bar (spec 030 §B3), pinned via safeAreaInset so
/// it never covers the tab bar or set rows. Driven by TimelineView off the
/// wall-clock `endsAt`, so backgrounding the app keeps the remaining time
/// honest with zero background-task machinery.
@available(iOS 17.0, macOS 14.0, *)
struct RestTimerOverlay: View {
  let timer: TodayWorkoutViewModel.RestTimerState
  let now: () -> Date
  let onAdjust: (Int) -> Void
  let onSkip: () -> Void

  var body: some View {
    TimelineView(.periodic(from: .now, by: 1)) { context in
      let remaining = max(0, timer.endsAt.timeIntervalSince(context.date))
      VStack(spacing: MeetPRSpacing.xs) {
        if remaining > 0 {
          countdown(remaining: remaining)
        } else {
          finished
        }
      }
      .padding(.horizontal, MeetPRSpacing.md)
      .padding(.vertical, MeetPRSpacing.sm)
      .frame(maxWidth: .infinity)
      .background(Color.MeetPR.surfaceElevated)
      .clipShape(.rect(cornerRadius: MeetPRRadius.md))
      .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
      .padding(.horizontal, MeetPRSpacing.md)
      .padding(.bottom, MeetPRSpacing.xs)
    }
    // Keyed to endsAt: starting/adjusting a timer cancels the stale
    // completion task, so an old 3s dismiss can't clear a fresh timer
    // (Codex review P1).
    .task(id: timer.endsAt) {
      let remaining = max(0, timer.endsAt.timeIntervalSince(now()))
      try? await Task.sleep(for: .seconds(remaining))
      guard !Task.isCancelled else { return }
      #if canImport(UIKit)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
      #endif
      try? await Task.sleep(for: .seconds(3))
      guard !Task.isCancelled else { return }
      onSkip()
    }
    .transition(.move(edge: .bottom).combined(with: .opacity))
  }

  private func countdown(remaining: TimeInterval) -> some View {
    VStack(spacing: MeetPRSpacing.xs) {
      HStack(spacing: MeetPRSpacing.md) {
        Image(systemName: "timer")
          .foregroundStyle(Color.MeetPR.gold500)
        Text(Self.minutesSeconds(remaining))
          .font(Font.MeetPR.mono(size: MeetPRFontMetrics.size22, weight: .bold))
          .foregroundStyle(Color.MeetPR.textPrimary)
          .contentTransition(.numericText())
        Spacer()
        Button("-30s") { onAdjust(-30) }
          .buttonStyle(.bordered)
          .tint(Color.MeetPR.textSecondary)
        Button("跳过") { onSkip() }
          .buttonStyle(.bordered)
          .tint(Color.MeetPR.goldText)
        Button("+30s") { onAdjust(30) }
          .buttonStyle(.bordered)
          .tint(Color.MeetPR.textSecondary)
      }
      ProgressView(
        value: max(0, min(1, remaining / Double(timer.totalSeconds)))
      )
      .tint(Color.MeetPR.gold500)
    }
    .accessibilityElement(children: .contain)
    .accessibilityLabel("组间休息，剩余 \(Self.minutesSeconds(remaining))")
  }

  private var finished: some View {
    HStack {
      Text("休息结束")
        .font(.MeetPR.body(size: MeetPRFontMetrics.size17, weight: .semibold))
        .foregroundStyle(Color.MeetPR.success)
      Spacer()
    }
  }

  private static func minutesSeconds(_ interval: TimeInterval) -> String {
    Duration.seconds(Int(interval.rounded()))
      .formatted(.time(pattern: .minuteSecond))
  }
}
