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
          PlanningStudentHeaderView(student: student)
        }

        VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
          Eyebrow("STEP 6")
          Text("递进 / 递减规则")
            .font(Font.MeetPR.title2)
            .foregroundStyle(Color.MeetPR.fgPrimary)
        }

        if viewModel.progressionRules.isEmpty {
          Card(accessibilityLabel: "Empty rules") {
            Text("还没有规则；未覆盖的周会默认同上周。")
              .font(Font.MeetPR.body)
              .foregroundStyle(Color.MeetPR.fgSecondary)
          }
        }

        ForEach(viewModel.progressionRules.sorted { $0.displayOrder < $1.displayOrder }) { rule in
          ProgressionRuleEditorCard(viewModel: viewModel, rule: rule)
        }

        PrimaryButton("+ 添加规则", isFullWidth: true) {
          Task {
            try? await viewModel.addRule(viewModel.makeDefaultProgressionRule())
          }
        }

        UncoveredRuleSummary(viewModel: viewModel)

        PrimaryButton("完成规则 — 预览 4 周", isFullWidth: true) {
          Task {
            try? await viewModel.proceedToStep7()
          }
        }
      }
      .padding(MeetPRSpacing.base)
    }
    .background(Color.MeetPR.bg)
    .navigationTitle("递进规则")
  }
}

@MainActor
private struct UncoveredRuleSummary: View {
  @Bindable var viewModel: PlanningViewModel

  var body: some View {
    Card(accessibilityLabel: "Uncovered progression summary") {
      VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
        Eyebrow("未被任何规则覆盖", color: Color.MeetPR.fgTertiary, showsRule: false)
        ForEach([2, 3, 4], id: \.self) { week in
          let uncovered = viewModel.uncoveredExercises(for: week)
          if !uncovered.isEmpty {
            Text("W\(week): \(uncovered.map(viewModel.exerciseName(for:)).joined(separator: "、"))")
              .font(Font.MeetPR.footnote)
              .foregroundStyle(Color.MeetPR.fgSecondary)
          }
        }
      }
    }
  }
}
