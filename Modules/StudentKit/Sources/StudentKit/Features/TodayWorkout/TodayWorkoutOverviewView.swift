import CoreModels
import DesignSystem
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct TodayWorkoutOverviewView: View {
  let day: StudentPlanDay
  let drafts: [TodayWorkoutSetRowDraft]
  let context: TodayWorkoutPlanContext?
  let references: [UUID: ExerciseReference]
  let lastDurationSeconds: Int?
  let onStart: () -> Void

  var body: some View {
    VStack(spacing: 0) {
      ScrollView {
        VStack(alignment: .leading, spacing: 20) {
          dateEyebrow

          Text(title)
            .font(.largeTitle.bold())
            .foregroundStyle(Color.MeetPR.fgPrimary)

          exerciseCard
          statistics
        }
        .padding(16)
      }
      .scrollIndicators(.hidden)

      PrimaryButton("开始训练", isFullWidth: true, action: onStart)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.MeetPR.bg)
    }
    .background(Color.MeetPR.bg)
  }

  private var dateEyebrow: some View {
    HStack(spacing: 8) {
      Text(
        day.date.formatted(
          .dateTime.month().day().weekday(.wide).locale(Locale(identifier: "zh_CN")))
      )
      .font(Font.MeetPR.monoLabel)
      .tracking(Font.MeetPR.monoLabelTracking)
      .foregroundStyle(Color.MeetPR.fgSecondary)

      Rectangle()
        .fill(Color.MeetPR.brandRed)
        .frame(width: 32, height: 1)
    }
  }

  private var title: String {
    let week = context.map { "W\($0.weekIndex)" } ?? "今日"
    let dayNumber = mondayOffset(day.date) + 1
    let prefix = context == nil ? week : "\(week)D\(dayNumber)"
    let dayName = MainLiftExerciseFamilyResolver.dayName(in: day) ?? "辅助日"
    return "\(prefix) · \(dayName)"
  }

  private var exerciseCard: some View {
    VStack(spacing: 0) {
      ForEach(sortedExercises) { exercise in
        exerciseRow(exercise)
        if exercise.id != sortedExercises.last?.id {
          Rectangle()
            .fill(Color.MeetPR.border)
            .frame(height: 1)
        }
      }
    }
    .padding(.horizontal, 16)
    .background(Color.MeetPR.surface1)
    .clipShape(.rect(cornerRadius: 12))
    .overlay {
      RoundedRectangle(cornerRadius: 12)
        .stroke(Color.MeetPR.border, lineWidth: 1)
    }
  }

  private func exerciseRow(_ exercise: StudentPlanExercise) -> some View {
    HStack(alignment: .top, spacing: 12) {
      VStack(alignment: .leading, spacing: 4) {
        Text(exercise.exercise.name)
          .font(.system(size: isPrimary(exercise) ? 14 : 13, weight: nameWeight(exercise)))
          .foregroundStyle(
            isPrimary(exercise) ? Color.MeetPR.fgPrimary : Color.MeetPR.fgSecondary)

        if let reference = references[exercise.exercise.id], reference.hasValue {
          Text(referenceText(reference))
            .font(Font.MeetPR.footnote)
            .foregroundStyle(Color.MeetPR.fgTertiary)
        }
      }
      Spacer()
      Text(targetText(exercise))
        .font(.system(size: 12, weight: .medium, design: .monospaced))
        .foregroundStyle(Color.MeetPR.fgSecondary)
        .multilineTextAlignment(.trailing)
    }
    .padding(.vertical, 14)
  }

  private var statistics: some View {
    HStack(spacing: 8) {
      statistic(label: "动作", value: "\(day.exercises.count)")
      statistic(label: "总组数", value: "\(drafts.count)")
      statistic(
        label: "上次时长",
        value: lastDurationSeconds.map(TrainingSessionTimer.text(seconds:)) ?? "—")
    }
  }

  private func statistic(label: String, value: String) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(label)
        .font(Font.MeetPR.monoLabel)
        .tracking(Font.MeetPR.monoLabelTracking)
        .foregroundStyle(Color.MeetPR.fgTertiary)
      Text(value)
        .font(.title3.bold().monospacedDigit())
        .foregroundStyle(Color.MeetPR.fgPrimary)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .background(Color.MeetPR.surface1)
    .clipShape(.rect(cornerRadius: 10))
    .overlay {
      RoundedRectangle(cornerRadius: 10)
        .stroke(Color.MeetPR.border, lineWidth: 1)
    }
  }

  private var sortedExercises: [StudentPlanExercise] {
    day.exercises.sorted { $0.sequenceIndex < $1.sequenceIndex }
  }

  private func isPrimary(_ exercise: StudentPlanExercise) -> Bool {
    exercise.exercise.exerciseType == .mainLift
      || exercise.exercise.exerciseType == .mainLiftVariation
  }

  private func nameWeight(_ exercise: StudentPlanExercise) -> Font.Weight {
    isPrimary(exercise) ? .bold : .regular
  }

  private func targetText(_ exercise: StudentPlanExercise) -> String {
    guard let firstSet = exercise.prescribedSets.first else { return "—" }
    let reps = firstSet.reps.map(String.init) ?? firstSet.repsMax.map { "≤\($0)" } ?? "—"
    var intensity: [String] = []
    if let weight = firstSet.weightKg {
      intensity.append("\(StudentFormatting.decimal(weight))kg")
    }
    if let rpe = firstSet.rpe {
      intensity.append("RPE \(StudentFormatting.decimal(rpe))")
    }
    let prescription = "\(exercise.prescribedSets.count)×\(reps)"
    return intensity.isEmpty
      ? prescription : "\(prescription) · \(intensity.joined(separator: " "))"
  }

  private func referenceText(_ reference: ExerciseReference) -> String {
    var parts: [String] = []
    if let last = reference.last {
      parts.append("上次 \(StudentFormatting.kilograms(last.weightKg))kg×\(last.reps)")
    }
    if let best = reference.best {
      parts.append("最佳 \(StudentFormatting.kilograms(best.weightKg))kg×\(best.reps)")
    }
    return parts.joined(separator: " · ")
  }

  private func mondayOffset(_ date: Date) -> Int {
    let weekday = Calendar.current.component(.weekday, from: date)
    return (weekday + 5) % 7
  }
}
