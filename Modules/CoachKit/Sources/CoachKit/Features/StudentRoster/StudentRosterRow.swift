import DesignSystem
import SwiftUI

@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct StudentRosterRow: View {
  let row: StudentRosterRowModel
  private let now: Date

  /// `now` 必须由 shell 的统一时钟传入——行内自取 `Date()` 会让同屏各行
  /// 落在不同时刻,且日切时不会跟着推进(review-loop 2026-07-30)。
  init(
    row: StudentRosterRowModel,
    now: Date
  ) {
    self.row = row
    self.now = now
  }

  var body: some View {
    VStack(spacing: MeetPRSpacing.point13) {
      HStack(spacing: MeetPRSpacing.point10) {
        Circle()
          .fill(isAbnormal ? Color.MeetPR.danger : Color.MeetPR.success)
          .frame(width: MeetPRSpacing.point9, height: MeetPRSpacing.point9)

        Text(row.student.displayName)
          .font(.MeetPR.body(size: MeetPRFontMetrics.size16, weight: .bold))
          .foregroundStyle(Color.MeetPR.textPrimary)
          .lineLimit(1)
          .frame(maxWidth: .infinity, alignment: .leading)

        if isAbnormal {
          Text(abnormalReason)
            .font(.MeetPR.body(size: MeetPRFontMetrics.size11, weight: .semibold))
            .foregroundStyle(Color.MeetPR.danger)
            .lineLimit(1)
        } else {
          Text(lastActiveText)
            .font(.MeetPR.mono(size: MeetPRFontMetrics.size11))
            .foregroundStyle(Color.MeetPR.textTertiary)
            .lineLimit(1)

          if plannedDays == 0 {
            Text(CoachRosterStrings.noPlan)
              .font(.MeetPR.body(size: MeetPRFontMetrics.size11, weight: .semibold))
              .foregroundStyle(Color.MeetPR.gold500)
              .padding(.horizontal, MeetPRSpacing.point9)
              .padding(.vertical, MeetPRSpacing.point3)
              .overlay {
                Capsule()
                  .stroke(
                    Color.MeetPR.gold500.opacity(0.4),
                    lineWidth: MeetPRSpacing.point1
                  )
              }
          }
        }
      }

      HStack(spacing: MeetPRSpacing.space2) {
        // 样机 1164:一段 = 一个计划训练日(`length: effOf(x)`),填满的段数 =
        // 已完成天数(`i < x.done`)——不是按百分比填充的三段式进度条。
        // 本周没有计划日时整组不画(样机的 0 段)。
        HStack(spacing: MeetPRSpacing.point3) {
          ForEach(0..<plannedDays, id: \.self) { index in
            Capsule()
              .fill(
                index < completedDays
                  ? Color.MeetPR.textPrimary
                  : Color.MeetPR.borderDefault
              )
              .frame(width: MeetPRSpacing.space4, height: MeetPRSpacing.point5)
          }
        }

        Text(
          CoachRosterStrings.weekProgress(
            completed: completedDays,
            planned: plannedDays
          )
        )
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size11))
        .foregroundStyle(Color.MeetPR.textTertiary)

        Spacer(minLength: MeetPRSpacing.zero)

        Text(CoachRosterStrings.completionRate)
          .font(.MeetPR.body(size: MeetPRFontMetrics.size11))
          .foregroundStyle(Color.MeetPR.textTertiary)

        Text("\(completionPercentage)%")
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size14, weight: .bold))
          .foregroundStyle(completionColor)
      }
    }
    .padding(.horizontal, MeetPRSpacing.space4)
    .padding(.vertical, MeetPRSpacing.point14)
    .meetPRCardSurface(.card)
    .contentShape(.rect)
    .accessibilityElement(children: .combine)
    .accessibilityLabel(row.student.displayName)
  }

  private var isAbnormal: Bool {
    !row.triageSignals.isEmpty
      || {
        if case .abnormal = row.student.status { return true }
        return false
      }()
  }

  private var plannedDays: Int {
    weekProgress.planned
  }

  private var completedDays: Int {
    weekProgress.completed
  }

  private var weekProgress: CoachWeekOverview.Progress {
    CoachWeekOverview.progress(trainingDays: row.trainingDays, now: now)
  }

  private var completionPercentage: Int {
    guard plannedDays > 0 else { return 0 }
    return Int((Double(completedDays) / Double(plannedDays) * 100).rounded())
  }

  private var completionColor: Color {
    switch completionPercentage {
    case 85...: Color.MeetPR.success
    case 65...: Color.MeetPR.gold500
    default: Color.MeetPR.danger
    }
  }

  private var lastActiveText: String {
    guard let lastActiveAt = row.lastActiveAt else {
      return CoachRosterStrings.noTrainingRecords
    }
    return CoachStudentFormatting.relativeText(lastActiveAt)
  }

  private var abnormalReason: String {
    if let daysMissed = row.triageSignals.compactMap({ signal -> Int? in
      if case .notTrained(let daysMissed) = signal { return daysMissed }
      return nil
    }).max() {
      return CoachRosterStrings.notTrainedReason(daysMissed)
    }
    if row.triageSignals.contains(.awaitingReply) {
      return CoachRosterStrings.waitingForReplyReason()
    }
    return row.statusText
  }
}
