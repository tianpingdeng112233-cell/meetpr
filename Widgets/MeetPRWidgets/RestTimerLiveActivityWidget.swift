import ActivityKit
import SwiftUI
import WidgetKit

struct RestTimerLiveActivityWidget: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: RestTimerActivityAttributes.self) { context in
      RestTimerLockScreenCard(state: context.state, isFinished: context.isStale)
        .activityBackgroundTint(RestTimerWidgetColors.background)
        .activitySystemActionForegroundColor(.white)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.center) {
          RestTimerExpandedContent(state: context.state, isFinished: context.isStale)
        }
      } compactLeading: {
        Image(systemName: "timer")
          .foregroundStyle(RestTimerWidgetColors.gold)
      } compactTrailing: {
        RestTimerCompactCountdown(state: context.state, isFinished: context.isStale)
      } minimal: {
        RestTimerMinimalCountdown(state: context.state, isFinished: context.isStale)
      }
      .keylineTint(RestTimerWidgetColors.gold)
    }
  }
}

private enum RestTimerWidgetColors {
  // DesignSystem `Color.MeetPR.gold500` dark token (#F5A623). The extension
  // keeps this local so it does not pull the app's package dependency graph.
  static let gold = Color(red: 245 / 255, green: 166 / 255, blue: 35 / 255)
  static let background = Color(red: 12 / 255, green: 12 / 255, blue: 14 / 255)
}

private struct RestTimerLockScreenCard: View {
  let state: RestTimerActivityAttributes.ContentState
  let isFinished: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 8) {
        Image(systemName: "timer")
          .foregroundStyle(RestTimerWidgetColors.gold)
        Text(WidgetStrings.restTimerTitle)
          .font(.headline)
          .foregroundStyle(.white)
      }

      RestTimerStatus(
        state: state, isFinished: isFinished, countdownFont: .title.monospacedDigit())
    }
    .padding()
  }
}

private struct RestTimerExpandedContent: View {
  let state: RestTimerActivityAttributes.ContentState
  let isFinished: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 6) {
        Image(systemName: "timer")
          .foregroundStyle(RestTimerWidgetColors.gold)
        Text(WidgetStrings.restTimerTitle)
          .font(.headline)
      }
      RestTimerStatus(
        state: state, isFinished: isFinished, countdownFont: .title2.monospacedDigit())
    }
    .padding(.horizontal, 4)
  }
}

// Live Activities do not run widget timelines: a `TimelineView` branch never
// re-evaluates after render, so the finished state must key off
// `ActivityViewContext.isStale` (stale date = `endsAt`, set by the app).
private struct RestTimerStatus: View {
  let state: RestTimerActivityAttributes.ContentState
  let isFinished: Bool
  let countdownFont: Font

  var body: some View {
    if isFinished {
      Text(WidgetStrings.restTimerFinished)
        .font(.headline)
        .bold()
        .foregroundStyle(RestTimerWidgetColors.gold)
    } else {
      VStack(alignment: .leading, spacing: 8) {
        Text(timerInterval: state.interval, countsDown: true)
          .font(countdownFont)
          .bold()
          .foregroundStyle(.white)

        ProgressView(timerInterval: state.interval, countsDown: true)
          .tint(RestTimerWidgetColors.gold)
      }
    }
  }
}

private struct RestTimerCompactCountdown: View {
  let state: RestTimerActivityAttributes.ContentState
  let isFinished: Bool

  var body: some View {
    if isFinished {
      Text(WidgetStrings.restTimerFinishedCompact)
        .foregroundStyle(RestTimerWidgetColors.gold)
    } else {
      Text(timerInterval: state.interval, countsDown: true, showsHours: false)
        .monospacedDigit()
        .foregroundStyle(.white)
    }
  }
}

private struct RestTimerMinimalCountdown: View {
  let state: RestTimerActivityAttributes.ContentState
  let isFinished: Bool

  var body: some View {
    if isFinished {
      Image(systemName: "checkmark")
        .foregroundStyle(RestTimerWidgetColors.gold)
    } else {
      Text(timerInterval: state.interval, countsDown: true, showsHours: false)
        .font(.caption2.monospacedDigit())
        .foregroundStyle(.white)
    }
  }
}

extension RestTimerActivityAttributes.ContentState {
  fileprivate var interval: ClosedRange<Date> {
    let start = endsAt.addingTimeInterval(-TimeInterval(totalSeconds))
    return start...max(start, endsAt)
  }
}
