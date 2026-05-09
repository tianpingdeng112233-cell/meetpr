import DesignSystem
import SwiftUI

@MainActor
@available(iOS 17.0, macOS 14.0, *)
public struct Step5SetIntensityView: View {
  @Bindable private var viewModel: PlanningViewModel

  public init(viewModel: PlanningViewModel) {
    self.viewModel = viewModel
  }

  public var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: MeetPRSpacing.lg) {
        if let student = viewModel.selectedStudent {
          PlanningStudentHeaderView(student: student)
        }

        VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
          Eyebrow("STEP 5")
          Text("Week 1 必填（基线）")
            .font(Font.MeetPR.title2)
            .foregroundStyle(Color.MeetPR.fgPrimary)
        }

        ForEach(viewModel.sortedDraftDays, id: \.id) { day in
          Step5DaySection(viewModel: viewModel, day: day)
        }

        PrimaryButton(nextButtonTitle, isDisabled: !isComplete, isFullWidth: true) {
          Task {
            try? await viewModel.proceedToStep6()
          }
        }
      }
      .padding(MeetPRSpacing.base)
    }
    .background(Color.MeetPR.bg)
    .navigationTitle("W1 强度")
  }

  private var isComplete: Bool {
    let exercises = viewModel.sortedDraftExercises
    return !exercises.isEmpty && exercises.allSatisfy { viewModel.setSpec(for: $0.id) != nil }
  }

  private var nextButtonTitle: String {
    if viewModel.planWeeks == 1 {
      "完成 W1 强度 — 预览本周"
    } else {
      "完成 W1 强度 — 进入规则配置"
    }
  }
}

@MainActor
private struct Step5DaySection: View {
  @Bindable var viewModel: PlanningViewModel
  let day: DraftPlanDay

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.md) {
      Eyebrow(PlanningDisplay.weekdayName(day.dayOfWeek), color: Color.MeetPR.fgTertiary)

      ForEach(viewModel.sortedExercises(in: day), id: \.id) { exercise in
        ExerciseSetEditorCard(viewModel: viewModel, draftExercise: exercise)
      }
    }
  }
}
