import CoreModels
import DesignSystem
import RepositoryContracts
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
public struct TrainingHistoryView: View {
  private let studentID: UUID
  @State private var viewModel: TrainingHistoryViewModel

  public init(
    studentID: UUID,
    plans: any StudentPlanRepository,
    logs: any StudentTrainingLogRepository
  ) {
    self.studentID = studentID
    self._viewModel = State(initialValue: TrainingHistoryViewModel(plans: plans, logs: logs))
  }

  public var body: some View {
    NavigationStack {
      Group {
        switch viewModel.state {
        case .idle, .loading:
          ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .loaded(let weeks, let logs):
          ScrollView {
            VStack(alignment: .leading, spacing: 18) {
              ForEach(weeks) { week in
                VStack(alignment: .leading, spacing: 12) {
                  Text("第 \(week.id) 周")
                    .font(.title3.bold())
                    .foregroundStyle(Color.MeetPR.fgPrimary)
                  ForEach(week.days) { day in
                    dayCard(day, logs: logs)
                  }
                }
              }
            }
            .padding()
          }
          .scrollContentBackground(.hidden)
        case .error(let message):
          ContentUnavailableView(
            "加载失败", systemImage: "exclamationmark.triangle", description: Text(message))
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(Color.MeetPR.bg)
      .navigationTitle("历史")
    }
    .task {
      if viewModel.state == .idle {
        await viewModel.load(studentID: studentID)
      }
    }
  }

  private func dayCard(_ day: StudentPlanDay, logs: [StudentSetLog]) -> some View {
    let progress = StudentFormatting.completedCount(for: day, logs: logs)
    return VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .firstTextBaseline) {
        VStack(alignment: .leading, spacing: 2) {
          Text(StudentFormatting.dayMonthFormatter.string(from: day.date))
            .font(.headline)
            .foregroundStyle(Color.MeetPR.fgPrimary)
          Text(StudentFormatting.weekdayFormatter.string(from: day.date))
            .font(.caption)
            .foregroundStyle(Color.MeetPR.fgSecondary)
        }
        Spacer()
        if day.exercises.isEmpty {
          Text("休息日")
            .font(.subheadline)
            .foregroundStyle(Color.MeetPR.fgTertiary)
        } else {
          Text("\(progress.completed)/\(progress.total) 组")
            .font(.subheadline.monospacedDigit())
            .foregroundStyle(
              progress.total > 0 && progress.completed == progress.total
                ? Color.MeetPR.green : Color.MeetPR.amber)
        }
      }

      if !day.exercises.isEmpty {
        ForEach(day.exercises) { exercise in
          exerciseBlock(exercise, logs: logs)
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(14)
    .background(Color.MeetPR.surface1)
    .overlay {
      RoundedRectangle(cornerRadius: 12)
        .stroke(Color.MeetPR.border, lineWidth: 1)
    }
    .clipShape(.rect(cornerRadius: 12))
  }

  private func exerciseBlock(_ exercise: StudentPlanExercise, logs: [StudentSetLog]) -> some View {
    VStack(alignment: .leading, spacing: 6) {
      Divider().overlay(Color.MeetPR.border)
      Text(exercise.exercise.name)
        .font(.subheadline.bold())
        .foregroundStyle(Color.MeetPR.fgPrimary)
      ForEach(exercise.prescribedSets) { set in
        let log = logs.first {
          $0.planExerciseID == exercise.id && $0.setIndex == set.setIndex
        }
        HStack {
          Text("第 \(set.setIndex + 1) 组")
            .font(.caption)
            .foregroundStyle(Color.MeetPR.fgTertiary)
          Spacer()
          if let log {
            Text(StudentFormatting.result(weightKg: log.weightKg, reps: log.reps, rpe: log.rpe))
              .font(.caption.monospacedDigit().bold())
              .foregroundStyle(log.completed ? Color.MeetPR.green : Color.MeetPR.fgSecondary)
          } else {
            Text(StudentFormatting.prescribed(set))
              .font(.caption.monospacedDigit())
              .foregroundStyle(Color.MeetPR.fgTertiary)
          }
        }
      }
    }
  }
}
