import DesignSystem
import SwiftUI

@MainActor
@available(iOS 17.0, macOS 14.0, *)
public struct Step1SelectDurationView: View {
  @Bindable private var viewModel: PlanningViewModel

  public init(viewModel: PlanningViewModel) {
    self.viewModel = viewModel
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.lg) {
      if let student = viewModel.selectedStudent {
        PlanningStudentHeaderView(student: student)
      }

      VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
        Eyebrow("STEP 1")
        Text("这次写几周？")
          .font(Font.MeetPR.title2)
          .foregroundStyle(Color.MeetPR.fgPrimary)
      }

      HStack(spacing: MeetPRSpacing.base) {
        DurationChoiceCard(
          title: "1 周",
          subtitle: "适应周或单周计划",
          isSelected: viewModel.planWeeks == 1,
          isDisabled: false
        ) {
          choose(weeks: 1)
        }

        DurationChoiceCard(
          title: "4 周",
          subtitle: fourWeekSubtitle,
          isSelected: viewModel.planWeeks == 4,
          isDisabled: isFourWeekDisabled
        ) {
          choose(weeks: 4)
        }
      }

      if isFourWeekDisabled {
        StatusBadge(status: .overdue, title: "评估期内仅 1 周")
      }

      Spacer()
    }
    .padding(MeetPRSpacing.base)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.MeetPR.bg)
    .navigationTitle("选计划长度")
  }

  private var isFourWeekDisabled: Bool {
    // planKind covers both the adaptationWeek intent and the in-evaluation
    // roster status (spec 033 §7).
    viewModel.planKind == .adaptation
  }

  private var fourWeekSubtitle: String {
    isFourWeekDisabled ? "评估期结束后可用" : "完整训练周期"
  }

  private func choose(weeks: Int) {
    viewModel.selectDuration(weeks)
    Task {
      try? await viewModel.goNext()
    }
  }
}

@MainActor
private struct DurationChoiceCard: View {
  let title: String
  let subtitle: String
  let isSelected: Bool
  let isDisabled: Bool
  let action: @MainActor () -> Void

  var body: some View {
    Button(action: action) {
      Card(accessibilityLabel: title) {
        VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
          Text(title)
            .font(Font.MeetPR.title2)
            .foregroundStyle(isDisabled ? Color.MeetPR.fgDisabled : Color.MeetPR.fgPrimary)

          Text(subtitle)
            .font(Font.MeetPR.footnote)
            .foregroundStyle(Color.MeetPR.fgTertiary)

          if isSelected {
            StatusBadge(status: .ready, title: "已选择")
          }
        }
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
      }
      .overlay {
        RoundedRectangle(cornerRadius: MeetPRRadius.lg)
          .stroke(isSelected ? Color.MeetPR.brandRed : .clear, lineWidth: 2)
      }
      .opacity(isDisabled ? 0.45 : 1)
    }
    .buttonStyle(.plain)
    .disabled(isDisabled)
  }
}

#if DEBUG
  #Preview("Step1SelectDurationView") {
    let viewModel = PlanningViewModel(
      repository: InMemoryPlanRepository.preview(),
      draftStore: PlanningPreviewFactory.makeStore()
    )

    Step1SelectDurationView(viewModel: viewModel)
      .task {
        await viewModel.bootstrap()
        if let student = viewModel.availableStudents.first {
          viewModel.selectStudent(student)
        }
      }
  }
#endif
