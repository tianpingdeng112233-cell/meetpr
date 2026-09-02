import CoreModels
import DesignSystem
import SwiftUI

@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct StudentOverviewSection: View {
  let summary: StudentOverviewSummary
  let readiness: ReadinessRowState
  let days: [StudentExecutionDay]
  let planWeekIndex: Int
  let shiftBadgeText: String?
  let now: Date
  let onSelectSection: (StudentDetailSection) -> Void
  let onRemindReadiness: () -> Void

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: MeetPRSpacing.point10) {
        trainingCard
        readinessCard
        feedbackCard
      }
      .padding(.horizontal, MeetPRSpacing.pageHorizontal)
      .padding(.bottom, MeetPRSpacing.point28)
    }
    .scrollIndicators(.hidden)
    .background(Color.MeetPR.bgBase)
  }

  private var trainingCard: some View {
    VStack(spacing: 0) {
      HStack {
        Text(CoachDetailStrings.weekTraining)
          .font(.MeetPR.body(size: MeetPRFontMetrics.size11, weight: .semibold))
          .foregroundStyle(Color.MeetPR.gold500)
        Spacer()
        Text(CoachDetailStrings.tapDayForDetails)
          .font(.MeetPR.body(size: MeetPRFontMetrics.size11))
          .foregroundStyle(Color.MeetPR.textTertiary)
      }
      .padding(.horizontal, MeetPRSpacing.space4)
      .padding(.top, MeetPRSpacing.point14)
      .padding(.bottom, MeetPRSpacing.point11)

      if trainingDays.isEmpty {
        Text(CoachDetailStrings.noTrainingThisWeek)
          .font(.MeetPR.body(size: MeetPRFontMetrics.size14))
          .foregroundStyle(Color.MeetPR.textTertiary)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, MeetPRSpacing.space4)
          .padding(.vertical, MeetPRSpacing.point13)
          .overlay(alignment: .top) {
            Rectangle()
              .fill(Color.MeetPR.borderHairline)
              .frame(height: MeetPRSpacing.point1)
          }
      } else {
        ForEach(Array(trainingDays.enumerated()), id: \.element.id) { index, day in
          NavigationLink {
            CoachDayDetailView(day: day)
          } label: {
            trainingDayRow(day, ordinal: index + 1)
          }
          .buttonStyle(PressScaleButtonStyle())
          .accessibilityIdentifier("coach.detail.day.\(day.id.timeIntervalSinceReferenceDate)")
        }
      }
    }
    .meetPRCardSurface(.card)
  }

  private func trainingDayRow(_ day: StudentExecutionDay, ordinal: Int) -> some View {
    HStack(spacing: MeetPRSpacing.point10) {
      VStack(alignment: .leading, spacing: MeetPRSpacing.point2) {
        Text(dayTitle(day, ordinal: ordinal))
          .font(.MeetPR.body(size: MeetPRFontMetrics.size14, weight: .bold))
          .foregroundStyle(Color.MeetPR.textPrimary)
          .lineLimit(1)
        Text(dateLine(day.date))
          .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
          .foregroundStyle(Color.MeetPR.textTertiary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)

      if day.planDay?.shiftedToDate != nil {
        Text(CoachDetailStrings.adjusted)
          .font(.MeetPR.body(size: MeetPRFontMetrics.size10, weight: .bold))
          .foregroundStyle(Color.MeetPR.gold500)
          .padding(.horizontal, MeetPRSpacing.space2)
          .padding(.vertical, MeetPRSpacing.point2)
          .background(Color.MeetPR.gold500.opacity(0.12))
          .clipShape(.capsule)
      } else if let shiftBadgeText, ordinal == 1 {
        Text(shiftBadgeText)
          .font(.MeetPR.body(size: MeetPRFontMetrics.size10, weight: .bold))
          .foregroundStyle(Color.MeetPR.gold500)
          .padding(.horizontal, MeetPRSpacing.space2)
          .padding(.vertical, MeetPRSpacing.point2)
          .background(Color.MeetPR.gold500.opacity(0.12))
          .clipShape(.capsule)
      }

      Text(dayState(day).text)
        .font(.MeetPR.body(size: MeetPRFontMetrics.size11, weight: .semibold))
        .foregroundStyle(dayState(day).color)
      Image(systemName: "chevron.right")
        .font(.MeetPR.system(size: MeetPRFontMetrics.size16, weight: .semibold))
        .foregroundStyle(Color.MeetPR.textDisabled)
    }
    .padding(.horizontal, MeetPRSpacing.space4)
    .padding(.vertical, MeetPRSpacing.point13)
    .overlay(alignment: .top) {
      Rectangle()
        .fill(Color.MeetPR.borderHairline)
        .frame(height: MeetPRSpacing.point1)
    }
  }

  private var readinessCard: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.point5) {
      Text(CoachDetailStrings.todayStatus)
        .font(.MeetPR.body(size: MeetPRFontMetrics.size11, weight: .semibold))
        .foregroundStyle(Color.MeetPR.textTertiary)

      switch readiness {
      case .loaded(let checkin):
        Text(CoachStudentFormatting.readinessScalesText(checkin))
          .font(.MeetPR.body(size: MeetPRFontMetrics.size15, weight: .bold))
          .foregroundStyle(Color.MeetPR.textPrimary)
        Text(CoachStudentFormatting.readinessFatigueText(checkin))
          .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
          .foregroundStyle(Color.MeetPR.textTertiary)
      case .notFiled:
        HStack(spacing: MeetPRSpacing.point10) {
          Text(CoachDetailStrings.todayNotFiled)
            .font(.MeetPR.body(size: MeetPRFontMetrics.size15, weight: .bold))
            .foregroundStyle(Color.MeetPR.textTertiary)
          Spacer()
          Button(CoachDetailStrings.remindToFile, action: onRemindReadiness)
            .font(.MeetPR.body(size: MeetPRFontMetrics.size12, weight: .semibold))
            .foregroundStyle(Color.MeetPR.textPrimary)
            .padding(.horizontal, MeetPRSpacing.point14)
            .padding(.vertical, MeetPRSpacing.point7)
            .overlay {
              Capsule()
                .stroke(Color.MeetPR.borderStrong, lineWidth: MeetPRSpacing.point1)
            }
            .buttonStyle(PressScaleButtonStyle())
        }
      case .unavailable:
        Text(CoachDetailStrings.statusUnavailable)
          .font(.MeetPR.body(size: MeetPRFontMetrics.size15, weight: .bold))
          .foregroundStyle(Color.MeetPR.textTertiary)
      }
    }
    .padding(MeetPRSpacing.point15)
    .meetPRCardSurface(.card)
  }

  private var feedbackCard: some View {
    Button {
      onSelectSection(summary.latestFeedback == nil ? .videos : .feedback)
    } label: {
      VStack(alignment: .leading, spacing: MeetPRSpacing.space1) {
        Text(CoachDetailStrings.recentFeedback)
          .font(.MeetPR.body(size: MeetPRFontMetrics.size11, weight: .semibold))
          .foregroundStyle(Color.MeetPR.textTertiary)
        if let feedback = summary.latestFeedback {
          Text(feedback.text)
            .font(.MeetPR.body(size: MeetPRFontMetrics.size15, weight: .bold))
            .foregroundStyle(Color.MeetPR.textPrimary)
            .lineLimit(1)
          Text(
            CoachDetailStrings.feedbackMeta(
              relativeTime: CoachStudentFormatting.relativeText(feedback.postedAt, now: now)
            )
          )
          .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
          .foregroundStyle(Color.MeetPR.textTertiary)
        } else {
          Text(CoachDetailStrings.noFeedback)
            .font(.MeetPR.body(size: MeetPRFontMetrics.size15, weight: .bold))
            .foregroundStyle(Color.MeetPR.textTertiary)
          Text(CoachDetailStrings.writeFirstFeedback)
            .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
            .foregroundStyle(Color.MeetPR.textTertiary)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(MeetPRSpacing.point15)
      .meetPRCardSurface(.card)
    }
    .buttonStyle(PressScaleButtonStyle())
  }

  private var trainingDays: [StudentExecutionDay] {
    days.filter { $0.planDay?.exercises.isEmpty == false }
  }

  private func dayTitle(_ day: StudentExecutionDay, ordinal: Int) -> String {
    let exerciseName =
      day.planDay?.exercises.first.map {
        CoachLocalization.exerciseName($0.exercise)
      } ?? CoachDetailStrings.training
    return "W\(planWeekIndex)D\(ordinal) · \(exerciseName)"
  }

  private func dateLine(_ date: Date) -> String {
    let calendar = CoachFeatureCalendar.calendar
    let month = calendar.component(.month, from: date)
    let day = calendar.component(.day, from: date)
    let weekday = calendar.component(.weekday, from: date)
    let weekdayText = CoachDetailStrings.weekday(weekday)
    return "\(month)/\(day) · \(weekdayText)"
  }

  private func dayState(_ day: StudentExecutionDay) -> (text: String, color: Color) {
    if day.completedSetCount > 0 {
      return (CoachDetailStrings.completed, Color.MeetPR.success)
    }
    if CoachFeatureCalendar.isSameDay(day.date, now) {
      return (CoachDetailStrings.today, Color.MeetPR.textTertiary)
    }
    return (CoachDetailStrings.notStarted, Color.MeetPR.textTertiary)
  }
}
