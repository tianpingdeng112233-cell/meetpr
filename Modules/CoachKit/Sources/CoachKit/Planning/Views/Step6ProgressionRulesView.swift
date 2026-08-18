import DesignSystem
import SwiftUI

@MainActor
@available(iOS 17.0, macOS 14.0, *)
public struct Step6ProgressionRulesView: View {
  @Bindable private var viewModel: PlanningViewModel

  public init(viewModel: PlanningViewModel) {
    self.viewModel = viewModel
  }

  public var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: MeetPRSpacing.lg) {
        if let student = viewModel.selectedStudent {
          PlanningStudentHeaderView(student: student, profile: viewModel.loadedProfile)
        }

        VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
          Eyebrow("STEP 5")
          Text(CoachPlanningStrings.progressionRulesTitle)
            .font(Font.MeetPR.title2)
            .foregroundStyle(Color.MeetPR.fgPrimary)
        }

        if viewModel.progressionRules.isEmpty {
          Card(accessibilityLabel: "Empty rules") {
            Text(CoachPlanningStrings.emptyRules)
              .font(Font.MeetPR.body)
              .foregroundStyle(Color.MeetPR.fgSecondary)
          }
        }

        ForEach(viewModel.progressionRules.sorted { $0.displayOrder < $1.displayOrder }) { rule in
          ProgressionRuleEditorCard(viewModel: viewModel, rule: rule)
        }

        PrimaryButton(CoachPlanningStrings.addRule, isFullWidth: true) {
          Task {
            try? await viewModel.addRule(viewModel.makeDefaultProgressionRule())
          }
        }

        UncoveredRuleSummary(viewModel: viewModel)

        PrimaryButton(CoachPlanningStrings.completeRules, isFullWidth: true) {
          Task {
            try? await viewModel.proceedToStep7()
          }
        }
      }
      .padding(MeetPRSpacing.base)
    }
    .background(Color.MeetPR.bg)
    .navigationTitle(CoachPlanningStrings.progressionRulesTitle)
    .scrollDismissesKeyboard(.interactively)
  }
}

@MainActor
private struct UncoveredRuleSummary: View {
  @Bindable var viewModel: PlanningViewModel

  var body: some View {
    Card(accessibilityLabel: "Uncovered progression summary") {
      VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
        Eyebrow(
          CoachPlanningStrings.uncoveredByRules,
          color: Color.MeetPR.fgTertiary,
          showsRule: false
        )
        ForEach([2, 3, 4], id: \.self) { week in
          let uncovered = viewModel.uncoveredExercises(for: week)
          if !uncovered.isEmpty {
            Text(
              CoachPlanningStrings.uncoveredWeek(
                week,
                exerciseNames: uncovered.map(viewModel.exerciseName(for:))
              )
            )
            .font(Font.MeetPR.footnote)
            .foregroundStyle(Color.MeetPR.fgSecondary)
          }
        }
      }
    }
  }
}
