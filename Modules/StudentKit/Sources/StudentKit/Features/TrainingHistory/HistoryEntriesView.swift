import CoreModels
import DesignSystem
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct HistoryEntriesView: View {
  let weeks: [TrainingHistoryViewModel.HistoryWeek]
  let logs: [StudentSetLog]
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
              .font(.MeetPR.display(size: MeetPRFontMetrics.size20))
              .foregroundStyle(Color.MeetPR.textPrimary)

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

      if !day.exercises.isEmpty {
        ForEach(day.exercises) { exercise in
          exerciseBlock(exercise, logs: logs)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(MeetPRSpacing.md)
    .background(Color.MeetPR.surfaceCard)
    .overlay {
      RoundedRectangle(cornerRadius: MeetPRRadius.md)
        .stroke(Color.MeetPR.borderDefault, lineWidth: 1)
    }
    .clipShape(.rect(cornerRadius: MeetPRRadius.md))
  }

  private func exerciseBlock(_ exercise: StudentPlanExercise, logs: [StudentSetLog]) -> some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
      Divider().overlay(Color.MeetPR.borderDefault)
      Text(exercise.exercise.name)
        .font(.MeetPR.body(size: MeetPRFontMetrics.size13, weight: .bold))
        .foregroundStyle(Color.MeetPR.textPrimary)

      if let note = CoachNoteDisplay.text(exercise.notes) {
        CoachNotePill(note: note, background: Color.MeetPR.surfaceElevated)
      }

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
        .font(.MeetPR.body(size: MeetPRFontMetrics.size13))
        .foregroundStyle(Color.MeetPR.textSecondary)
      Spacer()
      Picker("按动作筛选", selection: $selectedExerciseName) {
        Text("全部动作").tag(nil as String?)
        ForEach(exerciseNames, id: \.self) { name in
          Text(name).tag(name as String?)
        }
      }
      .pickerStyle(.menu)
      .tint(Color.MeetPR.goldText)
    }
    .padding(.horizontal, MeetPRSpacing.md)
    .padding(.vertical, MeetPRSpacing.sm)
    .background(Color.MeetPR.surfaceCard)
    .overlay {
      RoundedRectangle(cornerRadius: MeetPRRadius.md)
        .stroke(Color.MeetPR.borderDefault, lineWidth: 1)
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
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size17, weight: .semibold))
          .foregroundStyle(Color.MeetPR.textPrimary)
        Text(StudentFormatting.weekdayFormatter.string(from: day.date))
          .font(.MeetPR.body(size: MeetPRFontMetrics.size11, weight: .medium))
          .foregroundStyle(Color.MeetPR.textSecondary)
      }
      Spacer()
      if day.exercises.isEmpty {
        Text("休息日")
          .font(.MeetPR.body(size: MeetPRFontMetrics.size13))
          .foregroundStyle(Color.MeetPR.textMuted)
      } else {
        Text("\(progress.completed)/\(progress.total) 组")
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size13))
          .foregroundStyle(progressColor)
      }
    }
  }

  private var progressColor: Color {
    progress.total > 0 && progress.completed == progress.total
      ? Color.MeetPR.success
      : Color.MeetPR.goldText
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct HistorySetRow: View {
  let set: PrescribedSet
  let log: StudentSetLog?

  var body: some View {
    HStack {
      Text("第 \(set.setIndex + 1) 组")
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size11, weight: .medium))
        .foregroundStyle(Color.MeetPR.textMuted)
      Spacer()
      if let log {
        Text(StudentFormatting.result(weightKg: log.weightKg, reps: log.reps, rpe: log.rpe))
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size11, weight: .bold))
          .foregroundStyle(log.completed ? Color.MeetPR.success : Color.MeetPR.textSecondary)
      } else {
        Text(StudentFormatting.prescribed(set))
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size11, weight: .medium))
          .foregroundStyle(Color.MeetPR.textMuted)
      }
    }
  }
}
