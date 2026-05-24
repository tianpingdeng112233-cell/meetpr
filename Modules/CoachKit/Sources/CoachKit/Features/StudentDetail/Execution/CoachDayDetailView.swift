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
          ContentUnavailableView("休息日", systemImage: "moon")
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
    return Card(accessibilityLabel: exercise.exercise.name) {
      VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
        VStack(alignment: .leading, spacing: 2) {
          Text(exercise.exercise.name)
            .font(Font.MeetPR.headline)
            .foregroundStyle(Color.MeetPR.fgPrimary)
          Text("\(logs.count)/\(exercise.prescribedSets.count) 组已记录")
            .font(Font.MeetPR.footnote)
            .foregroundStyle(Color.MeetPR.fgSecondary)
        }

        if logs.isEmpty {
          Text("暂无已记录组")
            .font(Font.MeetPR.body)
            .foregroundStyle(Color.MeetPR.fgSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, MeetPRSpacing.sm)
        } else {
          ForEach(logs) { log in
            SetReadOnlyCell(
              setNumber: log.setIndex,
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
    Card(accessibilityLabel: "自由记录") {
      VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
        Text("自由记录")
          .font(Font.MeetPR.headline)
          .foregroundStyle(Color.MeetPR.fgPrimary)
        ForEach(day.logs) { log in
          SetReadOnlyCell(
            setNumber: log.setIndex,
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
