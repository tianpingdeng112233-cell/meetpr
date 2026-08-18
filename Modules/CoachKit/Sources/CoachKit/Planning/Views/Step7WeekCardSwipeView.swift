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
        PlanningStudentHeaderView(student: student, profile: viewModel.loadedProfile)
          .padding(.horizontal, MeetPRSpacing.base)
          .padding(.top, MeetPRSpacing.base)
      }

      ZStack(alignment: .leading) {
        weekTabs
        leadingEdgeBackSwipe
      }

      PrimaryButton(
        viewModel.isPublishing
          ? CoachPlanningStrings.publishing
          : CoachPlanningStrings.publishToStudent,
        isDisabled: viewModel.isPublishing,
        isFullWidth: true
      ) {
        Task { await viewModel.publish() }
      }
      .padding(.horizontal, MeetPRSpacing.base)
      .padding(.bottom, MeetPRSpacing.base)
    }
    .background(Color.MeetPR.bg)
    .navigationTitle(CoachPlanningStrings.weekCards)
    .alert(CoachPlanningStrings.almostThere, isPresented: incompleteAlertBinding) {
      Button(CoachPlanningStrings.acknowledge, role: .cancel) {
        viewModel.clearPublishFeedback()
      }
    } message: {
      Text(
        CoachPlanningStrings.publishCompletionIssues(
          viewModel.publishIssues.joined(separator: "\n")
        )
      )
    }
    .alert(CoachPlanningStrings.publishFailed, isPresented: errorAlertBinding) {
      Button(CoachPlanningStrings.acknowledge, role: .cancel) {
        viewModel.clearPublishFeedback()
      }
    } message: {
      Text(viewModel.publishError ?? CoachPlanningStrings.tryAgainLater)
    }
  }

  private var incompleteAlertBinding: Binding<Bool> {
    Binding(
      get: { !viewModel.publishIssues.isEmpty },
      set: { if !$0 { viewModel.clearPublishFeedback() } }
    )
  }

  private var errorAlertBinding: Binding<Bool> {
    Binding(
      get: { viewModel.publishError != nil },
      set: { if !$0 { viewModel.clearPublishFeedback() } }
    )
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

  private var leadingEdgeBackSwipe: some View {
    Color.clear
      .frame(width: 24)
      .contentShape(.rect)
      .gesture(
        DragGesture(minimumDistance: 10)
          .onEnded { value in
            guard value.translation.width > 60,
              abs(value.translation.height) < 40
            else { return }

            viewModel.goBack()
          }
      )
      .frame(maxHeight: .infinity, alignment: .leading)
  }
}
