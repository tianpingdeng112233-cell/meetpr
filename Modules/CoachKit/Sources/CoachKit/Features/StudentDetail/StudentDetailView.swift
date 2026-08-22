// swiftlint:disable file_length type_body_length
import Analytics
import CoreModels
import DesignSystem
import RepositoryContracts
import SwiftUI

@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct StudentDetailView: View {
  @Environment(\.coachNow) private var now
  @Environment(\.dismiss) private var dismiss
  @State private var viewModel: StudentDetailViewModel
  @State private var videoGridViewModel: StudentVideoGridViewModel
  @State private var growthViewModel: StudentGrowthViewModel
  @State private var evaluationViewModel: EvaluationBannerViewModel
  @State private var conversationOpener: CoachConversationOpener
  @State private var showEvaluationSummaryEditor = false
  @State private var showAdaptationPlanning = false
  @State private var conversationInitialDraft = ""
  private let context: CoachStudentDetailContext

  init(
    summary: CoachStudentSummary,
    context: CoachStudentDetailContext,
    onEvaluationCompleted: (@MainActor () -> Void)? = nil
  ) {
    _viewModel = State(
      initialValue: StudentDetailViewModel(
        summary: summary,
        plans: context.plans,
        trainingLogs: context.trainingLogs,
        feedback: context.feedback,
        videos: context.videos,
        readiness: context.readiness,
        profiles: context.profiles,
        now: { Date.distantPast }
      )
    )
    _videoGridViewModel = State(
      initialValue: StudentVideoGridViewModel(repository: context.videos)
    )
    _growthViewModel = State(
      initialValue: StudentGrowthViewModel(
        exerciseStats: context.exerciseStats
      )
    )
    _evaluationViewModel = State(
      initialValue: EvaluationBannerViewModel(
        studentID: summary.id,
        evaluations: context.evaluations,
        summaries: context.summaries,
        onCompleted: onEvaluationCompleted
      )
    )
    _conversationOpener = State(
      initialValue: CoachConversationOpener(chat: context.chat)
    )
    self.context = context
  }

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.point14) {
      detailHeader

      if CoachEvaluationSeal.shouldLoadEvaluation {
        if evaluationViewModel.loadFailed {
          EvaluationLoadFailureStrip {
            Task { await evaluationViewModel.load() }
          }
          .padding(.horizontal, MeetPRSpacing.pageHorizontal)
        } else if CoachEvaluationSeal.shouldRenderBanner(
          isBannerVisible: evaluationViewModel.isBannerVisible
        ) {
          EvaluationStatusBanner(
            viewModel: evaluationViewModel,
            hasPublishedPlan: viewModel.plan != nil,
            onSendAdaptationWeek: { showAdaptationPlanning = true },
            onViewAdaptationWeek: { viewModel.select(.overview) },
            onOpenSummary: { showEvaluationSummaryEditor = true }
          )
          .padding(.horizontal, MeetPRSpacing.pageHorizontal)
        }
      }

      sectionTabs
      content
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .refreshable {
          if viewModel.selectedSection == .growth {
            await growthViewModel.load(studentID: viewModel.summary.id, now: now)
          } else {
            await viewModel.refresh(now: now)
          }
        }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(Color.MeetPR.bgBase)
    .hideNavigationBar()
    .coachFullScreenDestination()
    .navigationDestination(isPresented: $showEvaluationSummaryEditor) {
      evaluationSummaryEditor
    }
    .navigationDestination(item: conversationDestinationBinding) { conversation in
      if let chat = context.chat {
        CoachConversationDestination(
          conversationID: conversation.id,
          chat: chat,
          studentName: conversationOpener.destinationStudentName,
          initialDraft: conversationInitialDraft,
          studentStatus: viewModel.summary.status
        )
      }
    }
    .modifier(
      AdaptationPlanningPresenter(
        isPresented: $showAdaptationPlanning,
        student: viewModel.summary,
        context: context
      )
    )
    .alert(
      CoachStrings.unableToOpenConversation,
      isPresented: conversationErrorBinding
    ) {
      Button(CoachStrings.confirmation, role: .cancel) {
        conversationOpener.dismissError()
      }
    }
    .task {
      Analytics.shared.screen(.coachStudentDetail)
      Analytics.shared.coachOpenedStudent(id: viewModel.summary.id)
      await viewModel.loadIfNeeded(now: now)
      if CoachEvaluationSeal.shouldLoadEvaluation {
        await evaluationViewModel.load()
      }
    }
  }

  private var detailHeader: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.point14) {
      backRow
      HStack(alignment: .center, spacing: MeetPRSpacing.point10) {
        Text(viewModel.summary.displayName)
          .font(.MeetPR.display(size: MeetPRFontMetrics.size32))
          .foregroundStyle(Color.MeetPR.textPrimary)
          .lineLimit(1)
          .minimumScaleFactor(0.7)
        statusPill
      }
      planCard
    }
    .padding(.horizontal, MeetPRSpacing.pageHorizontal)
    .padding(.top, MeetPRSpacing.point6)
  }

  private var backRow: some View {
    HStack {
      Button {
        dismiss()
      } label: {
        HStack(spacing: MeetPRSpacing.point5) {
          Image(systemName: "chevron.left")
            .font(.MeetPR.system(size: MeetPRFontMetrics.size20, weight: .semibold))
          Text(CoachDetailStrings.backToStudents)
            .font(.MeetPR.body(size: MeetPRFontMetrics.size14))
        }
        .foregroundStyle(Color.MeetPR.textSecondary)
      }
      .buttonStyle(PressScaleButtonStyle(scale: 0.95))
      .accessibilityLabel(CoachDetailStrings.backToStudents)
      .accessibilityIdentifier("coach.detail.back")

      Spacer()

      if context.chat != nil {
        Button {
          openConversation(initialDraft: "")
        } label: {
          Image(systemName: "message")
            .font(.MeetPR.system(size: MeetPRFontMetrics.size18))
            .foregroundStyle(Color.MeetPR.textPrimary)
            .frame(width: 38, height: 38)
            .meetPRCardSurface(.card)
            .clipShape(.circle)
        }
        .buttonStyle(PressScaleButtonStyle(scale: 0.94))
        .disabled(conversationOpener.isOpening)
        .accessibilityLabel(CoachStrings.sendMessage)
        .accessibilityIdentifier("coach.detail.chat")
      }
    }
  }

  private var statusPill: some View {
    Text(statusPresentation.text)
      .font(.MeetPR.body(size: MeetPRFontMetrics.size11, weight: .semibold))
      .foregroundStyle(statusPresentation.color)
      .padding(.horizontal, MeetPRSpacing.point10)
      .padding(.vertical, MeetPRSpacing.point3)
      .overlay {
        Capsule()
          .stroke(statusPresentation.color.opacity(0.35), lineWidth: MeetPRSpacing.point1)
      }
  }

  private var statusPresentation: (text: String, color: Color) {
    switch viewModel.summary.status {
    case .active:
      (CoachDetailStrings.active, Color.MeetPR.success)
    case .abnormal:
      (CoachDetailStrings.needsAttention, Color.MeetPR.danger)
    case .inEvaluation(let days, let hours):
      (
        days > 0
          ? CoachDetailStrings.evaluationDays(days)
          : CoachDetailStrings.evaluationHours(hours),
        Color.MeetPR.gold500
      )
    }
  }

  private var planCard: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.point11) {
      HStack(spacing: MeetPRSpacing.space2) {
        Text(CoachDetailStrings.weekRunningTitle(calendarWeek))
          .font(.MeetPR.body(size: MeetPRFontMetrics.size14, weight: .bold))
          .foregroundStyle(Color.MeetPR.textPrimary)
        Text(
          "· "
            + CoachDetailStrings.weekProgress(
              completed: viewModel.overview.completedTrainingDays,
              total: viewModel.overview.plannedTrainingDays
            )
        )
        .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
        .foregroundStyle(Color.MeetPR.textTertiary)
      }

      ProgressView(value: completionFraction)
        .progressViewStyle(.linear)
        .tint(Color.MeetPR.success)
        .background(Color.MeetPR.borderDefault)
        .clipShape(.rect(cornerRadius: MeetPRRadius.micro))
        .frame(height: MeetPRSpacing.point6)

      HStack(spacing: MeetPRSpacing.point9) {
        Button {
          openConversation(initialDraft: CoachDetailStrings.trainingReminderDraft)
        } label: {
          planActionLabel(CoachDetailStrings.remindTraining)
        }
        .buttonStyle(PressScaleButtonStyle(scale: 0.97))
        .disabled(context.chat == nil || conversationOpener.isOpening)
        .accessibilityIdentifier("coach.detail.remindTraining")

        Button {
        } label: {
          planActionLabel(CoachDetailStrings.weekSummary)
        }
        .buttonStyle(.plain)
        .disabled(true)
        .accessibilityHint(CoachDetailStrings.weekSummaryUnavailable)
        .accessibilityIdentifier("coach.detail.weekSummary")
      }
    }
    .padding(MeetPRSpacing.space4)
    .meetPRCardSurface(.card)
  }

  private func planActionLabel(_ title: String) -> some View {
    Text(title)
      .font(.MeetPR.body(size: MeetPRFontMetrics.size13, weight: .semibold))
      .foregroundStyle(Color.MeetPR.textPrimary)
      .frame(maxWidth: .infinity)
      .padding(.vertical, MeetPRSpacing.point11)
      .overlay {
        Capsule()
          .stroke(Color.MeetPR.borderStrong, lineWidth: MeetPRSpacing.point1)
      }
  }

  private var sectionTabs: some View {
    ScrollView(.horizontal) {
      HStack(spacing: MeetPRSpacing.point6) {
        ForEach(StudentDetailSection.allCases) { section in
          Button {
            viewModel.select(section)
          } label: {
            Text(CoachDetailStrings.sectionTitle(section))
              .font(.MeetPR.body(size: MeetPRFontMetrics.size13, weight: .semibold))
              .foregroundStyle(
                viewModel.selectedSection == section
                  ? Color.MeetPR.inkOnCTAFill
                  : Color.MeetPR.textTertiary
              )
              .padding(.horizontal, MeetPRSpacing.point11)
              .padding(.vertical, MeetPRSpacing.space2)
              .background(
                viewModel.selectedSection == section
                  ? Color.MeetPR.textPrimary
                  : Color.MeetPR.surfaceCard
              )
              .clipShape(.rect(cornerRadius: MeetPRRadius.chip))
          }
          .buttonStyle(PressScaleButtonStyle(scale: 0.95))
          .accessibilityIdentifier("coach.detail.tab.\(section.rawValue)")
        }
      }
      .padding(.horizontal, MeetPRSpacing.pageHorizontal)
    }
    .scrollIndicators(.hidden)
  }

  @ViewBuilder
  private var content: some View {
    switch viewModel.state {
    case .idle, .loading:
      VStack(spacing: MeetPRSpacing.point10) {
        Spacer()
        ProgressView()
          .tint(Color.MeetPR.gold500)
        Text(CoachDetailStrings.loading)
          .font(.MeetPR.mono(size: MeetPRFontMetrics.size12))
          .foregroundStyle(Color.MeetPR.textTertiary)
        Spacer()
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    case .failed(let message):
      failureCard(message)
    case .loaded:
      sectionContent
    }
  }

  private func failureCard(_ message: String) -> some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.space2) {
      Text(CoachDetailStrings.loadFailed)
        .font(.MeetPR.body(size: MeetPRFontMetrics.size15, weight: .bold))
        .foregroundStyle(Color.MeetPR.danger)
      Text(message)
        .font(.MeetPR.body(size: MeetPRFontMetrics.size14))
        .foregroundStyle(Color.MeetPR.textPrimary)
      Text(CoachDetailStrings.pullToRetry)
        .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
        .foregroundStyle(Color.MeetPR.textTertiary)
    }
    .padding(MeetPRSpacing.space4)
    .meetPRCardSurface(.card)
    .padding(.horizontal, MeetPRSpacing.pageHorizontal)
  }

  @ViewBuilder
  private var sectionContent: some View {
    switch viewModel.selectedSection {
    case .overview:
      StudentOverviewSection(
        summary: viewModel.overview,
        readiness: viewModel.todayReadiness,
        days: viewModel.executionDays,
        planWeekIndex: viewModel.plan?.weekIndex ?? 1,
        shiftBadgeText: viewModel.planShiftBadgeText,
        now: now,
        onSelectSection: viewModel.select,
        onRemindReadiness: {
          openConversation(initialDraft: CoachDetailStrings.readinessReminderDraft)
        }
      )
    case .videos:
      StudentVideoGridView(
        videos: viewModel.videos,
        unavailable: viewModel.videosUnavailable,
        now: now,
        planDays: viewModel.plannedDays,
        logs: viewModel.executionDays.flatMap(\.logs),
        feedbackVideoIDs: Set(viewModel.feedbackItems.compactMap(\.videoID)),
        viewModel: videoGridViewModel
      )
    case .growth:
      StudentGrowthView(
        studentID: viewModel.summary.id,
        now: now,
        viewModel: growthViewModel
      )
    case .feedback:
      CoachFeedbackHistoryView(
        feedback: viewModel.feedbackItems,
        days: viewModel.plannedDays,
        now: now
      )
    case .profile:
      StudentProfileSection(state: viewModel.profileState, now: now)
    }
  }

  private var calendarWeek: Int {
    CoachFeatureCalendar.calendar.component(.weekOfYear, from: now)
  }

  private var completionFraction: Double {
    guard viewModel.overview.plannedTrainingDays > 0 else { return 0 }
    return Double(viewModel.overview.completedTrainingDays)
      / Double(viewModel.overview.plannedTrainingDays)
  }

  private func openConversation(initialDraft: String) {
    conversationInitialDraft = initialDraft
    Task {
      await conversationOpener.openConversation(
        withOtherParty: viewModel.summary.id,
        studentName: viewModel.summary.displayName
      )
    }
  }

  private var conversationDestinationBinding: Binding<ChatConversation?> {
    Binding(
      get: { conversationOpener.destination },
      set: { destination in
        if destination == nil {
          conversationInitialDraft = ""
          conversationOpener.dismissDestination()
        }
      }
    )
  }

  private var conversationErrorBinding: Binding<Bool> {
    Binding(
      get: { conversationOpener.errorMessage != nil },
      set: { isPresented in
        if !isPresented {
          conversationOpener.dismissError()
        }
      }
    )
  }

  private var evaluationSummaryEditor: some View {
    EvaluationSummaryEditorView(
      viewModel: EvaluationSummaryEditorViewModel(
        student: viewModel.summary,
        evaluation: evaluationViewModel.evaluation,
        summaries: context.summaries,
        evaluations: context.evaluations,
        profiles: context.profiles,
        onEvaluationCompleted: { completed in
          evaluationViewModel.markEvaluationCompleted(completed)
        }
      ),
      context: context
    )
  }
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
private struct EvaluationLoadFailureStrip: View {
  let onRetry: () -> Void

  var body: some View {
    HStack(spacing: MeetPRSpacing.space2) {
      Text(CoachDetailStrings.evaluationLoadFailed)
        .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
        .foregroundStyle(Color.MeetPR.textTertiary)
      Spacer()
      Button(CoachDetailStrings.retry, action: onRetry)
        .font(.MeetPR.body(size: MeetPRFontMetrics.size12, weight: .semibold))
        .foregroundStyle(Color.MeetPR.textPrimary)
    }
    .padding(MeetPRSpacing.space3)
    .meetPRCardSurface(.card)
  }
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
private struct AdaptationPlanningPresenter: ViewModifier {
  @Binding var isPresented: Bool
  let student: CoachStudentSummary
  let context: CoachStudentDetailContext

  func body(content: Content) -> some View {
    #if os(iOS)
      content.fullScreenCover(isPresented: $isPresented) {
        planning
      }
    #else
      content.sheet(isPresented: $isPresented) {
        planning
      }
    #endif
  }

  private var planning: some View {
    PlanningCoordinatorView(
      repository: context.planning,
      draftStore: context.draftStore,
      intent: .adaptationWeek(student),
      profiles: context.profiles
    )
  }
}
// swiftlint:enable file_length type_body_length
