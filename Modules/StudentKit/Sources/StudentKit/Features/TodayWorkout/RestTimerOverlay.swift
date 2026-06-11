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

  @State private var firedCompletionHaptic = false

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
      .background(Color.MeetPR.surface1)
      .clipShape(.rect(cornerRadius: MeetPRRadius.md))
      .shadow(color: .black.opacity(0.3), radius: 10, y: 4)
      .padding(.horizontal, MeetPRSpacing.md)
      .padding(.bottom, MeetPRSpacing.xs)
      .onChange(of: remaining <= 0) { _, isDone in
        guard isDone, !firedCompletionHaptic else { return }
        firedCompletionHaptic = true
        #if canImport(UIKit)
          UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
        Task {
          try? await Task.sleep(for: .seconds(3))
          onSkip()
        }
      }
    }
    .transition(.move(edge: .bottom).combined(with: .opacity))
  }

  private func countdown(remaining: TimeInterval) -> some View {
    VStack(spacing: MeetPRSpacing.xs) {
      HStack(spacing: MeetPRSpacing.md) {
        Image(systemName: "timer")
          .foregroundStyle(Color.MeetPR.brandRed)
        Text(Self.minutesSeconds(remaining))
          .font(Font.MeetPR.title2.monospacedDigit())
          .foregroundStyle(Color.MeetPR.fgPrimary)
          .contentTransition(.numericText())
        Spacer()
        Button("-30s") { onAdjust(-30) }
          .buttonStyle(.bordered)
          .tint(Color.MeetPR.fgSecondary)
        Button("跳过") { onSkip() }
          .buttonStyle(.bordered)
          .tint(Color.MeetPR.brandRed)
        Button("+30s") { onAdjust(30) }
          .buttonStyle(.bordered)
          .tint(Color.MeetPR.fgSecondary)
      }
      ProgressView(
        value: max(0, min(1, remaining / Double(timer.totalSeconds)))
      )
      .tint(Color.MeetPR.brandRed)
    }
    .accessibilityElement(children: .contain)
    .accessibilityLabel("组间休息，剩余 \(Self.minutesSeconds(remaining))")
  }

  private var finished: some View {
    HStack {
      Text("休息结束 💪")
        .font(Font.MeetPR.bodyEmphasis)
        .foregroundStyle(Color.MeetPR.green)
      Spacer()
    }
  }

  private static func minutesSeconds(_ interval: TimeInterval) -> String {
    let total = Int(interval.rounded())
    return String(format: "%d:%02d", total / 60, total % 60)
  }
}
