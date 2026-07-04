import CoreModels
import DesignSystem
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct HistoryEntriesView: View {
  let weeks: [TrainingHistoryViewModel.HistoryWeek]
  let logs: [StudentSetLog]
  var reviews: [String: SessionReview] = [:]
  @Binding var selectedExerciseName: String?

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: MeetPRSpacing.base) {
        ExerciseFilterPicker(
          exerciseNames: exerciseNames,
          selectedExerciseName: $selectedExerciseName
        )

        ForEach(filteredWeeks) { week in
          VStack(alignment: .leading, spacing: MeetPRSpacing.md) {
            Text("第 \(week.id) 周")
              .font(Font.MeetPR.headline)
              .foregroundStyle(Color.MeetPR.fgPrimary)

            ForEach(week.days) { day in
              dayCard(day, logs: logs)
            }
          }
        }
      }
      .padding(MeetPRSpacing.md)
    }
    .scrollContentBackground(.hidden)
  }

  private var exerciseNames: [String] {
    let names = weeks.flatMap { week in
      week.days.flatMap { day in
        day.exercises.map { $0.exercise.name }
      }
    }
    return Array(Set(names)).sorted {
      $0.localizedStandardCompare($1) == .orderedAscending
    }
  }

  private var filteredWeeks: [TrainingHistoryViewModel.HistoryWeek] {
    guard let selectedExerciseName else { return weeks }
    return weeks.compactMap { week in
      let filteredDays = week.days.filter { day in
        day.exercises.contains { $0.exercise.name == selectedExerciseName }
      }
      guard !filteredDays.isEmpty else { return nil }
      return TrainingHistoryViewModel.HistoryWeek(id: week.id, days: filteredDays)
    }
  }

  private func dayCard(_ day: StudentPlanDay, logs: [StudentSetLog]) -> some View {
    let progress = StudentFormatting.completedCount(for: day, logs: logs)
    return VStack(alignment: .leading, spacing: MeetPRSpacing.md) {
      HistoryDayHeader(day: day, progress: progress)

      // 当日一句话回顾 (spec 051 §1): 写下的东西必须能被自己看回来。
      if let review = reviews[SoloSessionViewModel.dayString(day.date, calendar: .current)] {
        Text(reviewLine(review))
          .font(Font.MeetPR.caption)
          .foregroundStyle(Color.MeetPR.fgSecondary)
      }

      if !day.exercises.isEmpty {
        ForEach(day.exercises) { exercise in
          exerciseBlock(exercise, logs: logs)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(MeetPRSpacing.md)
    .background(Color.MeetPR.surface1)
    .overlay {
      RoundedRectangle(cornerRadius: MeetPRRadius.md)
        .stroke(Color.MeetPR.border, lineWidth: 1)
    }
    .clipShape(.rect(cornerRadius: MeetPRRadius.md))
  }

  private func reviewLine(_ review: SessionReview) -> String {
    var line = "「\(review.feeling)」"
    if let rpe = review.sessionRPE {
      line += " · 整场 RPE \(rpe)"
    }
    return line
  }

  private func exerciseBlock(_ exercise: StudentPlanExercise, logs: [StudentSetLog]) -> some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
      Divider().overlay(Color.MeetPR.border)
      Text(exercise.exercise.name)
        .font(Font.MeetPR.footnote.bold())
        .foregroundStyle(Color.MeetPR.fgPrimary)

      ForEach(exercise.prescribedSets) { set in
        HistorySetRow(
          set: set,
          log: logs.first { $0.planExerciseID == exercise.id && $0.setIndex == set.setIndex }
        )
      }
    }
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct ExerciseFilterPicker: View {
  let exerciseNames: [String]
  @Binding var selectedExerciseName: String?

  var body: some View {
    HStack {
      Text("按动作筛选")
        .font(Font.MeetPR.footnote)
        .foregroundStyle(Color.MeetPR.fgSecondary)
      Spacer()
      Picker("按动作筛选", selection: $selectedExerciseName) {
        Text("全部动作").tag(nil as String?)
        ForEach(exerciseNames, id: \.self) { name in
          Text(name).tag(name as String?)
        }
      }
      .pickerStyle(.menu)
      .tint(Color.MeetPR.brandRed)
    }
    .padding(.horizontal, MeetPRSpacing.md)
    .padding(.vertical, MeetPRSpacing.sm)
    .background(Color.MeetPR.surface1)
    .overlay {
      RoundedRectangle(cornerRadius: MeetPRRadius.md)
        .stroke(Color.MeetPR.border, lineWidth: 1)
    }
    .clipShape(.rect(cornerRadius: MeetPRRadius.md))
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct HistoryDayHeader: View {
  let day: StudentPlanDay
  let progress: (completed: Int, total: Int)

  var body: some View {
    HStack(alignment: .firstTextBaseline) {
      VStack(alignment: .leading, spacing: 2) {
        Text(StudentFormatting.dayMonthFormatter.string(from: day.date))
          .font(Font.MeetPR.bodyEmphasis)
          .foregroundStyle(Color.MeetPR.fgPrimary)
        Text(StudentFormatting.weekdayFormatter.string(from: day.date))
          .font(Font.MeetPR.caption)
          .foregroundStyle(Color.MeetPR.fgSecondary)
      }
      Spacer()
      if day.exercises.isEmpty {
        Text("休息日")
          .font(Font.MeetPR.footnote)
          .foregroundStyle(Color.MeetPR.fgTertiary)
      } else {
        Text("\(progress.completed)/\(progress.total) 组")
          .font(Font.MeetPR.footnote.monospacedDigit())
          .foregroundStyle(progressColor)
      }
    }
  }

  private var progressColor: Color {
    progress.total > 0 && progress.completed == progress.total
      ? Color.MeetPR.green
      : Color.MeetPR.amber
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct HistorySetRow: View {
  let set: PrescribedSet
  let log: StudentSetLog?

  var body: some View {
    HStack {
      Text("第 \(set.setIndex + 1) 组")
        .font(Font.MeetPR.caption)
        .foregroundStyle(Color.MeetPR.fgTertiary)
      Spacer()
      if let log {
        Text(StudentFormatting.result(weightKg: log.weightKg, reps: log.reps, rpe: log.rpe))
          .font(Font.MeetPR.caption.monospacedDigit().bold())
          .foregroundStyle(log.completed ? Color.MeetPR.green : Color.MeetPR.fgSecondary)
      } else {
        Text(StudentFormatting.prescribed(set))
          .font(Font.MeetPR.caption.monospacedDigit())
          .foregroundStyle(Color.MeetPR.fgTertiary)
      }
    }
  }
}
