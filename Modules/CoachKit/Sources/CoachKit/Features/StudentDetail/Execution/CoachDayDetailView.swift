import CoreModels
import DesignSystem
import SwiftUI

@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct CoachDayDetailView: View {
  let day: StudentExecutionDay

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: MeetPRSpacing.base) {
        if let planDay = day.planDay, !planDay.exercises.isEmpty {
          ForEach(planDay.exercises) { exercise in
            exerciseCard(exercise)
          }
        } else if !day.logs.isEmpty {
          freeLogCard
        } else {
          ContentUnavailableView(
            CoachStudentDetailStrings.text("coach.execution.restDay"), systemImage: "moon"
          )
          .frame(maxWidth: .infinity)
        }
      }
      .padding(MeetPRSpacing.base)
    }
    .navigationTitle(CoachStudentFormatting.fullDateText(day.date))
    .background(Color.MeetPR.bg)
  }

  private func exerciseCard(_ exercise: StudentPlanExercise) -> some View {
    let logs = logs(for: exercise)
    let exerciseName = CoachLocalization.exerciseName(exercise.exercise)
    return Card(accessibilityLabel: exerciseName) {
      VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
        VStack(alignment: .leading, spacing: 2) {
          Text(exerciseName)
            .font(Font.MeetPR.headline)
            .foregroundStyle(Color.MeetPR.fgPrimary)
          Text(
            CoachLocalization.localized(
              "coach.execution.loggedSetsFraction \(logs.count) \(exercise.prescribedSets.count)")
          )
          .font(Font.MeetPR.footnote)
          .foregroundStyle(Color.MeetPR.fgSecondary)
        }

        if logs.isEmpty {
          Text(CoachStudentDetailStrings.text("coach.execution.noLoggedSets"))
            .font(Font.MeetPR.body)
            .foregroundStyle(Color.MeetPR.fgSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, MeetPRSpacing.sm)
        } else {
          ForEach(logs) { log in
            SetReadOnlyCell(
              setIndex: log.setIndex,
              weightKg: log.weightKg,
              reps: log.reps,
              rpe: log.rpe,
              isCompleted: log.completed
            )
          }
        }
      }
    }
  }

  private var freeLogCard: some View {
    Card(accessibilityLabel: CoachStudentDetailStrings.text("coach.execution.freeLog")) {
      VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
        Text(CoachStudentDetailStrings.text("coach.execution.freeLog"))
          .font(Font.MeetPR.headline)
          .foregroundStyle(Color.MeetPR.fgPrimary)
        ForEach(day.logs) { log in
          SetReadOnlyCell(
            setIndex: log.setIndex,
            weightKg: log.weightKg,
            reps: log.reps,
            rpe: log.rpe,
            isCompleted: log.completed
          )
        }
      }
    }
  }

  private func logs(for exercise: StudentPlanExercise) -> [StudentSetLog] {
    day.logs
      .filter { $0.planExerciseID == exercise.id }
      .sorted { $0.setIndex < $1.setIndex }
  }
}
