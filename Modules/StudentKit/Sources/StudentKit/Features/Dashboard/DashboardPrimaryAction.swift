import CoreModels
import DesignSystem
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct DashboardPrimaryAction: View {
  let day: StudentPlanDay
  let onStart: () -> Void
  let onStartFrameChange: (CGRect) -> Void
  let isStartHidden: Bool

  var body: some View {
    GoldCTA(
      StudentStrings.localized(.dashboardPrimaryAction001),
      sub: DashboardTodayPresentation.dayName(day),
      variant: .primary,
      icon: .play,
      showsShimmer: true,
      action: onStart
    )
    .onGeometryChange(for: CGRect.self) { proxy in
      proxy.frame(in: .global)
    } action: { frame in
      onStartFrameChange(frame)
    }
    .opacity(isStartHidden ? 0 : 1)
    .allowsHitTesting(!isStartHidden)
    .accessibilityHidden(isStartHidden)
  }
}

@available(iOS 17.0, macOS 14.0, *)
struct DashboardCompletedAction: View {
  let completedDay: StudentPlanDay
  let nextDay: StudentPlanDay?
  let canUndo: Bool
  let isUpdating: Bool
  let onUndo: () -> Void
  let onContinue: () -> Void

  var body: some View {
    VStack(spacing: 13) {
      VStack(spacing: 8) {
        Image(systemName: "checkmark.circle.fill")
          .font(.MeetPR.system(size: MeetPRFontMetrics.size34, weight: .semibold))
          .foregroundStyle(Color.MeetPR.success)
        Text(
          StudentStrings.replacing(
            .dashboardPrimaryAction002,
            values: ["\(DashboardTodayPresentation.code(for: completedDay))"])
        )
        .font(.MeetPR.body(size: MeetPRFontMetrics.size18, weight: .bold))
        .foregroundStyle(Color.MeetPR.textPrimary)
        if canUndo {
          Button(StudentStrings.localized(.dashboardPrimaryAction003), action: onUndo)
            .font(.MeetPR.body(size: MeetPRFontMetrics.size13))
            .foregroundStyle(Color.MeetPR.textMuted)
            .underline()
            .buttonStyle(.plain)
            .disabled(isUpdating)
        }
      }
      .frame(maxWidth: .infinity)
      .padding(18)
      .background(Color.MeetPR.surfaceCard)
      .clipShape(.rect(cornerRadius: 16))

      if let nextDay {
        VStack(alignment: .leading, spacing: 8) {
          Text(
            StudentStrings.replacing(
              .dashboardPrimaryAction004,
              values: ["\(DashboardTodayPresentation.code(for: nextDay))"])
          )
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size12))
          .foregroundStyle(Color.MeetPR.gold500)
          DashboardSequenceDaySummary(day: nextDay)
        }
        .padding(15)
        .background(Color.MeetPR.bgInset)
        .clipShape(.rect(cornerRadius: 16))

        Button(StudentStrings.localized(.dashboardPrimaryAction005), action: onContinue)
          .font(.MeetPR.body(size: MeetPRFontMetrics.size14, weight: .bold))
          .foregroundStyle(Color.MeetPR.textPrimary)
          .frame(maxWidth: .infinity, minHeight: 46)
          .overlay { Capsule().stroke(Color.MeetPR.borderStrong, lineWidth: 1) }
          .buttonStyle(.plain)
      }
    }
  }
}

@available(iOS 17.0, macOS 14.0, *)
struct DashboardCycleCompletedAction: View {
  let days: [StudentPlanDay]

  var body: some View {
    let ordered = StudentPlanSequence(days: days).orderedDays
    let finalWeek = ordered.last?.weekNumber ?? 1
    VStack(spacing: 10) {
      Image(systemName: "trophy.fill")
        .font(.MeetPR.system(size: MeetPRFontMetrics.size34, weight: .semibold))
        .foregroundStyle(Color.MeetPR.gold500)
      Text(StudentStrings.replacing(.dashboardPrimaryAction006, values: ["\(finalWeek)"]))
        .font(.MeetPR.body(size: MeetPRFontMetrics.size18, weight: .bold))
        .foregroundStyle(Color.MeetPR.textPrimary)
      Text(
        StudentStrings.replacing(
          .dashboardPrimaryAction007, values: ["\(finalWeek)", "\(ordered.count)"])
      )
      .font(.MeetPR.mono(size: MeetPRFontMetrics.size12))
      .foregroundStyle(Color.MeetPR.textMuted)
      Text(StudentStrings.localized(.dashboardPrimaryAction008))
        .font(.MeetPR.body(size: MeetPRFontMetrics.size13))
        .foregroundStyle(Color.MeetPR.textSecondary)
        .multilineTextAlignment(.center)
        .lineSpacing(3)
    }
    .frame(maxWidth: .infinity)
    .padding(22)
    .background(Color.MeetPR.surfaceCard)
    .clipShape(.rect(cornerRadius: 16))
  }
}

@available(iOS 17.0, macOS 14.0, *)
struct DashboardSequenceDaySummary: View {
  let day: StudentPlanDay

  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      Text(DashboardTodayPresentation.dayName(day))
        .font(.MeetPR.body(size: MeetPRFontMetrics.size16, weight: .bold))
        .foregroundStyle(Color.MeetPR.textPrimary)
      Text(DashboardTodayPresentation.exerciseSummary(day))
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size12))
        .foregroundStyle(Color.MeetPR.textMuted)
      Text(
        StudentStrings.replacing(
          .dashboardPrimaryAction009,
          values: ["\(DashboardTodayPresentation.recommendedDateText(day.scheduledDate))"])
      )
      .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
      .foregroundStyle(Color.MeetPR.textDim)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}
