import DesignSystem
import SwiftUI

@MainActor
@available(iOS 17.0, macOS 14.0, *)
public struct Step7WeekCardSwipeView: View {
  @Bindable private var viewModel: PlanningViewModel

  public init(viewModel: PlanningViewModel) {
    self.viewModel = viewModel
  }

  public var body: some View {
    VStack(spacing: MeetPRSpacing.base) {
      if let student = viewModel.selectedStudent {
        PlanningStudentHeaderView(student: student)
          .padding(.horizontal, MeetPRSpacing.base)
          .padding(.top, MeetPRSpacing.base)
      }

      weekTabs

      PrimaryButton("进入发布 (TODO spec 008)", isFullWidth: true) {
        Task {
          try? await viewModel.proceedToStep8()
        }
      }
      .padding(.horizontal, MeetPRSpacing.base)
      .padding(.bottom, MeetPRSpacing.base)
    }
    .background(Color.MeetPR.bg)
    .navigationTitle("周卡片")
  }

  private var weekCount: Int {
    max(1, viewModel.draftPlan?.planWeeks ?? viewModel.planWeeks ?? 1)
  }

  @ViewBuilder
  private var weekTabs: some View {
    #if os(iOS)
      TabView(selection: $viewModel.currentPreviewWeek) {
        weekCards
      }
      .tabViewStyle(.page(indexDisplayMode: .never))
      .onChange(of: viewModel.currentPreviewWeek) { _, week in
        viewModel.setCurrentPreviewWeek(week)
      }
    #else
      TabView(selection: $viewModel.currentPreviewWeek) {
        weekCards
      }
      .onChange(of: viewModel.currentPreviewWeek) { _, week in
        viewModel.setCurrentPreviewWeek(week)
      }
    #endif
  }

  private var weekCards: some View {
    ForEach(1...weekCount, id: \.self) { week in
      WeekCardView(viewModel: viewModel, weekNumber: week)
        .tag(week)
        .padding(.horizontal, MeetPRSpacing.base)
    }
  }
}
