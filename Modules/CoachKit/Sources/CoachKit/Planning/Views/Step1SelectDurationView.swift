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
        PlanningStudentHeaderView(student: student, profile: viewModel.loadedProfile)
      }

      VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
        Eyebrow("STEP 1")
        Text(CoachPlanningStrings.durationPrompt)
          .font(Font.MeetPR.title2)
          .foregroundStyle(Color.MeetPR.fgPrimary)
      }

      DurationChoiceCard(
        title: durationTitle,
        subtitle: durationSubtitle,
        isSelected: viewModel.planWeeks == durationWeeks
      ) {
        choose(weeks: durationWeeks)
      }

      Spacer()
    }
    .padding(MeetPRSpacing.base)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.MeetPR.bg)
    .navigationTitle(CoachPlanningStrings.durationTitle)
  }

  /// Regular plans are always a full 4-week block; the single week is the
  /// adaptation-week exception (spec 033 §7). Each context offers only its one
  /// valid length, so the step shows a single card.
  private var durationWeeks: Int {
    viewModel.planKind == .adaptation ? 1 : 4
  }

  private var durationTitle: String {
    CoachPlanningStrings.weekCount(durationWeeks)
  }

  private var durationSubtitle: String {
    viewModel.planKind == .adaptation
      ? CoachPlanningStrings.adaptationWeek
      : CoachPlanningStrings.fullTrainingCycle
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
  let action: @MainActor () -> Void

  var body: some View {
    Button(action: action) {
      Card(accessibilityLabel: title) {
        VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
          Text(title)
            .font(Font.MeetPR.title2)
            .foregroundStyle(Color.MeetPR.fgPrimary)

          Text(subtitle)
            .font(Font.MeetPR.footnote)
            .foregroundStyle(Color.MeetPR.fgTertiary)

          if isSelected {
            StatusBadge(status: .ready, title: CoachPlanningStrings.selected)
          }
        }
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
      }
      .overlay {
        RoundedRectangle(cornerRadius: MeetPRRadius.lg)
          .stroke(isSelected ? Color.MeetPR.brandRed : .clear, lineWidth: 2)
      }
    }
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
