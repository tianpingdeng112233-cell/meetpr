import DesignSystem
import SwiftUI

@MainActor
@available(iOS 17.0, macOS 14.0, *)
public struct PlanningCoordinatorView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var viewModel: PlanningViewModel

  public init(repository: any PlanRepository, draftStore: DraftStore) {
    _viewModel = State(
      initialValue: PlanningViewModel(repository: repository, draftStore: draftStore)
    )
  }

  public var body: some View {
    @Bindable var viewModel = viewModel

    NavigationStack(path: $viewModel.path) {
      Step0SelectStudentView(viewModel: viewModel)
        .navigationTitle("新计划")
        .navigationDestination(for: PlanningStep.self) { step in
          destination(for: step)
        }
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("关闭") {
              dismiss()
            }
          }
        }
    }
    .task {
      await viewModel.bootstrap()
    }
    .onChange(of: viewModel.didFinish) { _, didFinish in
      if didFinish {
        dismiss()
      }
    }
  }

  @ViewBuilder
  private func destination(for step: PlanningStep) -> some View {
    switch step {
    case .selectStudent:
      Step0SelectStudentView(viewModel: viewModel)
    case .selectDuration:
      Step1SelectDurationView(viewModel: viewModel)
    case .assignFrequency:
      Step2AssignFrequencyView(viewModel: viewModel)
    case .selectMainLifts:
      Step3SelectMainLiftsView(viewModel: viewModel)
    case .selectAccessories:
      Step4SelectAccessoriesView(viewModel: viewModel)
    case .fillW1Intensity:
      Step5SetIntensityView(viewModel: viewModel)
    case .configureRules:
      Step6ProgressionRulesView(viewModel: viewModel)
    case .previewWeekCards:
      Step7WeekCardSwipeView(viewModel: viewModel)
    }
  }
}

#if DEBUG
  #Preview("PlanningCoordinatorView") {
    PlanningCoordinatorView(
      repository: InMemoryPlanRepository.preview(),
      draftStore: PlanningPreviewFactory.makeStore()
    )
    .background(Color.MeetPR.bg)
  }
#endif
