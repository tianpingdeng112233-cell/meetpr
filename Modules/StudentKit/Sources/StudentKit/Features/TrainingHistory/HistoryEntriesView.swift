import CoreModels
import DesignSystem
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct HistoryEntriesView: View {
  let weeks: [TrainingHistoryViewModel.HistoryWeek]
  let logs: [StudentSetLog]
  @Binding var selectedExerciseName: String?

  static func setLabel(forZeroBasedIndex setIndex: Int) -> String {
    "第 \(SetIndexDisplay.number(forZeroBasedIndex: setIndex)) 组"
  }

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

  @State private var showsSheet = false

  var body: some View {
    Button {
      showsSheet = true
    } label: {
      HStack {
        Text(StudentStrings.filterTitle)
          .font(.MeetPR.body(size: MeetPRFontMetrics.size13))
          .foregroundStyle(Color.MeetPR.textSecondary)
        Spacer()
        Text(selectedExerciseName ?? StudentStrings.filterAllExercises)
          .font(.MeetPR.body(size: MeetPRFontMetrics.size14, weight: .semibold))
          .foregroundStyle(Color.MeetPR.goldText)
        Image(systemName: "chevron.up.chevron.down")
          .font(.MeetPR.system(size: MeetPRFontMetrics.size11, weight: .semibold))
          .foregroundStyle(Color.MeetPR.textDim)
      }
      .padding(.horizontal, MeetPRSpacing.md)
      .padding(.vertical, MeetPRSpacing.sm)
      .frame(minHeight: MeetPRSpacing.minimumHitTarget)
      .background(Color.MeetPR.surfaceCard)
      .overlay {
        RoundedRectangle(cornerRadius: MeetPRRadius.md)
          .stroke(Color.MeetPR.borderDefault, lineWidth: 1)
      }
      .clipShape(.rect(cornerRadius: MeetPRRadius.md))
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(
      StudentStrings.filterAccessibilityLabel(
        selectedExerciseName ?? StudentStrings.filterAllExercises
      )
    )
    .sheet(isPresented: $showsSheet) {
      ExerciseFilterSheet(
        exerciseNames: exerciseNames,
        selectedExerciseName: $selectedExerciseName
      )
      .presentationDetents([.medium, .large])
    }
  }
}

/// Searchable exercise filter (David 2026-07-28): a flat menu stops scaling
/// once the history spans many exercises.
@available(iOS 17.0, macOS 14.0, *)
private struct ExerciseFilterSheet: View {
  let exerciseNames: [String]
  @Binding var selectedExerciseName: String?

  @Environment(\.dismiss) private var dismiss
  @State private var query = ""
  @FocusState private var searchFocused: Bool

  private var filteredNames: [String] {
    let trimmed = query.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return exerciseNames }
    return exerciseNames.filter { $0.localizedCaseInsensitiveContains(trimmed) }
  }

  var body: some View {
    VStack(spacing: MeetPRSpacing.zero) {
      HStack(spacing: MeetPRSpacing.point9) {
        Image(systemName: "magnifyingglass")
          .font(.MeetPR.system(size: MeetPRFontMetrics.size14, weight: .semibold))
          .foregroundStyle(Color.MeetPR.textDim)
        TextField(StudentStrings.filterSearchPlaceholder, text: $query)
          .font(.MeetPR.body(size: MeetPRFontMetrics.size15))
          .foregroundStyle(Color.MeetPR.textPrimary)
          .tint(Color.MeetPR.gold500)
          .focused($searchFocused)
          .submitLabel(.done)
        if !query.isEmpty {
          Button {
            query = ""
          } label: {
            Image(systemName: "xmark.circle.fill")
              .font(.MeetPR.system(size: MeetPRFontMetrics.size14))
              .foregroundStyle(Color.MeetPR.textDim)
              .frame(
                width: MeetPRSpacing.minimumHitTarget,
                height: MeetPRSpacing.minimumHitTarget
              )
              .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .accessibilityLabel(StudentStrings.filterClearSearch)
        }
      }
      .padding(.horizontal, MeetPRSpacing.point14)
      .frame(minHeight: MeetPRSpacing.minimumHitTarget)
      .background(Color.MeetPR.surfaceCard)
      .clipShape(.rect(cornerRadius: MeetPRRadius.md))
      .overlay {
        RoundedRectangle(cornerRadius: MeetPRRadius.md)
          .stroke(Color.MeetPR.borderDefault, lineWidth: 1)
      }
      .padding(.horizontal, MeetPRSpacing.space4)
      .padding(.top, MeetPRSpacing.space4)
      .padding(.bottom, MeetPRSpacing.point10)

      ScrollView {
        LazyVStack(spacing: MeetPRSpacing.zero) {
          if query.trimmingCharacters(in: .whitespaces).isEmpty {
            filterRow(title: StudentStrings.filterAllExercises, value: nil)
          }
          ForEach(filteredNames, id: \.self) { name in
            filterRow(title: name, value: name)
          }
          if filteredNames.isEmpty {
            Text(StudentStrings.filterNoMatch(query))
              .font(.MeetPR.body(size: MeetPRFontMetrics.size13))
              .foregroundStyle(Color.MeetPR.textMuted)
              .frame(maxWidth: .infinity)
              .padding(.vertical, MeetPRSpacing.space5)
          }
        }
      }
    }
    .background(Color.MeetPR.bgBase.ignoresSafeArea())
    .onAppear { searchFocused = true }
  }

  private func filterRow(title: String, value: String?) -> some View {
    Button {
      selectedExerciseName = value
      dismiss()
    } label: {
      HStack {
        Text(title)
          .font(.MeetPR.body(size: MeetPRFontMetrics.size15, weight: .medium))
          .foregroundStyle(Color.MeetPR.textPrimary)
        Spacer()
        if selectedExerciseName == value {
          Image(systemName: "checkmark")
            .font(.MeetPR.system(size: MeetPRFontMetrics.size14, weight: .bold))
            .foregroundStyle(Color.MeetPR.gold500)
            .accessibilityHidden(true)
        }
      }
      .padding(.horizontal, MeetPRSpacing.space4)
      .frame(minHeight: MeetPRSpacing.point52)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(selectedExerciseName == value ? [.isSelected] : [])
    .overlay(alignment: .bottom) {
      Rectangle()
        .fill(Color.MeetPR.borderHairline)
        .frame(height: 1)
        .padding(.leading, MeetPRSpacing.space4)
    }
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
      Text(HistoryEntriesView.setLabel(forZeroBasedIndex: set.setIndex))
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
