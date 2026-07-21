// swiftlint:disable file_length type_body_length
import Analytics
import CoreModels
import DesignSystem
import RepositoryContracts
import SwiftUI

@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct StudentDetailView: View {
  @Bindable private var viewModel: StudentDetailViewModel
  @State private var videoGridViewModel: StudentVideoGridViewModel
  @State private var growthViewModel: StudentGrowthViewModel
  @State private var evaluationViewModel: EvaluationBannerViewModel
  @State private var conversationOpener: CoachConversationOpener
  private let context: CoachStudentDetailContext
  @State private var showComposer = false
  @State private var showSummaryEditor = false
  @State private var showAdaptationPlanning = false

  init(
    summary: CoachStudentSummary,
    context: CoachStudentDetailContext,
    onEvaluationCompleted: (@MainActor () -> Void)? = nil
  ) {
    viewModel = StudentDetailViewModel(
      summary: summary,
      plans: context.plans,
      trainingLogs: context.trainingLogs,
      feedback: context.feedback,
      videos: context.videos,
      readiness: context.readiness
    )
    _videoGridViewModel = State(
      initialValue: StudentVideoGridViewModel(repository: context.videos)
    )
    _growthViewModel = State(
      initialValue: StudentGrowthViewModel(
        plans: context.plans,
        trainingLogs: context.trainingLogs,
        profiles: context.profiles,
        familyMapProvider: context.familyMapProvider
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
    VStack(spacing: 0) {
      header

      if evaluationViewModel.loadFailed {
        EvaluationLoadFailureStrip {
          Task { await evaluationViewModel.load() }
        }
        .padding(.horizontal, MeetPRSpacing.base)
        .padding(.top, MeetPRSpacing.sm)
      } else if evaluationViewModel.isBannerVisible {
        EvaluationStatusBanner(
          viewModel: evaluationViewModel,
          hasPublishedPlan: viewModel.plan != nil,
          onSendAdaptationWeek: { showAdaptationPlanning = true },
          onViewAdaptationWeek: { viewModel.select(.execution) },
          onOpenSummary: { showSummaryEditor = true }
        )
        .padding(.horizontal, MeetPRSpacing.base)
        .padding(.top, MeetPRSpacing.sm)
      }

      sectionTabs

      content
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Spec 029 §risk 5: auto fetch once on appear + pull-to-refresh as
        // the explicit retry path (the "下拉刷新重试" copy in the video wall
        // and readiness row points here). Growth keeps its own cache, so the
        // pull refreshes whichever data the visible section reads.
        .refreshable { [viewModel, growthViewModel] in
          if await viewModel.selectedSection == .growth {
            await growthViewModel.load(studentID: viewModel.summary.id)
          } else {
            await viewModel.refresh()
          }
        }
    }
    .background(Color.MeetPR.bg)
    .hideNavigationBar()
    .sheet(isPresented: $showComposer) {
      FeedbackComposerView(
        studentID: viewModel.summary.id,
        studentName: viewModel.summary.displayName,
        days: viewModel.plannedDays,
        repository: context.feedback
      ) { item in
        viewModel.appendPostedFeedback(item)
      }
    }
    .navigationDestination(isPresented: $showSummaryEditor) {
      summaryEditor
    }
    .navigationDestination(item: conversationDestinationBinding) { conversation in
      if let chat = context.chat {
        CoachConversationDestination(
          conversationID: conversation.id,
          chat: chat
        )
      }
    }
    .onChange(of: showSummaryEditor) { _, isShowing in
      if !isShowing {
        // Returning from the editor: refresh the overview summary card.
        Task { await evaluationViewModel.reloadSummary() }
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
      await viewModel.loadIfNeeded()
      await evaluationViewModel.load()
    }
  }

  // MARK: - Header (custom large title + student identity + status)

  /// Reskins the mock's nav bar (back chevron · name · ellipsis) into the house
  /// large-title header: a back affordance row, the student's real
  /// `displayName`, a status line, and — when the active feedback section
  /// exposes it — the 写反馈 compose action that previously lived in the
  /// nav-bar toolbar (preserved verbatim, just relocated into the header).
  private var header: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
      backRow

      HStack(alignment: .firstTextBaseline, spacing: MeetPRSpacing.md) {
        Text(viewModel.summary.displayName)
          .font(.system(size: 34, weight: .heavy))
          .foregroundStyle(Color.MeetPR.fgPrimary)
          .lineLimit(1)
          .minimumScaleFactor(0.7)
        Spacer(minLength: MeetPRSpacing.sm)
        let badge = statusBadge
        StatusBadge(status: badge.status, title: badge.title)
      }

      Text(statusLine)
        .font(Font.MeetPR.monoLabel)
        .tracking(Font.MeetPR.monoLabelTracking)
        .foregroundStyle(Color.MeetPR.fgSecondary)
    }
    .padding(.horizontal, MeetPRSpacing.base)
    .padding(.top, MeetPRSpacing.sm)
    .padding(.bottom, MeetPRSpacing.md)
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  @Environment(\.dismiss) private var dismiss

  private var backRow: some View {
    HStack {
      Button {
        dismiss()
      } label: {
        HStack(spacing: 4) {
          Image(systemName: "chevron.left")
          Text("学员")
        }
        .font(Font.MeetPR.body)
        .foregroundStyle(Color.MeetPR.fgPrimary)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("返回学员列表")

      Spacer()

      if context.chat != nil {
        Button {
          Task {
            await conversationOpener.openConversation(
              withOtherParty: viewModel.summary.id
            )
          }
        } label: {
          Image(systemName: "message")
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(Color.MeetPR.fgPrimary)
            .frame(width: 36, height: 36)
            .background(Color.MeetPR.surface1)
            .clipShape(Circle())
            .overlay { Circle().stroke(Color.MeetPR.border, lineWidth: 1) }
        }
        .buttonStyle(.plain)
        .disabled(conversationOpener.isOpening)
        .accessibilityLabel(CoachStrings.sendMessage)
      }

      if viewModel.selectedSection == .feedback {
        Button {
          showComposer = true
        } label: {
          Image(systemName: "square.and.pencil")
            .font(.system(size: 18))
            .foregroundStyle(Color.MeetPR.fgPrimary)
            .frame(width: 36, height: 36)
            .background(Color.MeetPR.surface1)
            .clipShape(Circle())
            .overlay { Circle().stroke(Color.MeetPR.border, lineWidth: 1) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("写反馈")
      }
    }
  }

  private var conversationDestinationBinding: Binding<ChatConversation?> {
    Binding(
      get: { conversationOpener.destination },
      set: { destination in
        if destination == nil {
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

  /// Status line beneath the name. Mirrors the mock's "教练 · 学员" identity
  /// framing using the real `CoachStudentStatus` rather than fabricated
  /// W3D1 live-session strings.
  private var statusLine: String {
    switch viewModel.summary.status {
    case .inEvaluation(let days, let hours):
      if days > 0 { return "学员 · 评估期 · 还剩 \(days) 天" }
      return "学员 · 评估期 · 还剩 \(hours) 小时"
    case .active:
      return "学员 · 活跃"
    case .abnormal:
      return "学员 · 异常"
    }
  }

  /// Maps the real lifecycle status to a `StatusBadge`. No fabricated copy —
  /// the evaluation countdown text comes straight from the status payload.
  private var statusBadge: (status: StatusBadge.Status, title: String) {
    switch viewModel.summary.status {
    case .inEvaluation(let days, let hours):
      let amount = days > 0 ? "评估期 \(days)天" : "评估期 \(hours)时"
      return (.pending, amount)
    case .active:
      return (.ready, "活跃")
    case .abnormal:
      return (.overdue, "异常")
    }
  }

  // MARK: - Section tabs (reskinned segmented picker)

  /// The five-section switch is core behavior (drives `selectedSection`, which
  /// every sub-view and the toolbar depend on), so the segmented `Picker` is
  /// preserved verbatim — only its surround is restyled to the house card:
  /// a mono section label over a bordered surface that contains the picker.
  private var sectionTabs: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
      Eyebrow("学员档案")

      Picker("", selection: $viewModel.selectedSection) {
        ForEach(StudentDetailSection.allCases) { section in
          Text(section.title).tag(section)
        }
      }
      .pickerStyle(.segmented)
    }
    .padding(MeetPRSpacing.base)
  }

  private var summaryEditor: some View {
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

  // MARK: - Content states (reskinned loading / failure)

  @ViewBuilder
  private var content: some View {
    switch viewModel.state {
    case .idle, .loading:
      VStack(spacing: MeetPRSpacing.md) {
        Spacer()
        ProgressView()
          .tint(Color.MeetPR.brandRed)
        Text("加载学员详情…")
          .font(Font.MeetPR.monoLabel)
          .tracking(Font.MeetPR.monoLabelTracking)
          .foregroundStyle(Color.MeetPR.fgTertiary)
        Spacer()
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    case .failed(let message):
      detailFailureCard(message)
    case .loaded:
      sectionContent
    }
  }

  /// House-style failure surface in place of the bare `ContentUnavailableView`,
  /// preserving the failed-state message verbatim.
  private func detailFailureCard(_ message: String) -> some View {
    VStack {
      Spacer()
      VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
        Eyebrow("加载失败", color: Color.MeetPR.brandRed)
        Text(message)
          .font(Font.MeetPR.body)
          .foregroundStyle(Color.MeetPR.fgPrimary)
        Text("下拉刷新重试")
          .font(Font.MeetPR.footnote)
          .foregroundStyle(Color.MeetPR.fgSecondary)
      }
      .padding(MeetPRSpacing.base)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(Color.MeetPR.surface1)
      .clipShape(.rect(cornerRadius: MeetPRRadius.lg))
      .overlay {
        RoundedRectangle(cornerRadius: MeetPRRadius.lg)
          .stroke(Color.MeetPR.border, lineWidth: 1)
      }
      .padding(.horizontal, MeetPRSpacing.base)
      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  @ViewBuilder
  private var sectionContent: some View {
    switch viewModel.selectedSection {
    case .overview:
      StudentOverviewSection(
        summary: viewModel.overview,
        readiness: viewModel.todayReadiness,
        recentVideos: viewModel.recentVideos,
        videosUnavailable: viewModel.videosUnavailable,
        evaluationSummary: evaluationViewModel.summary,
        onSelectSection: { section in
          viewModel.select(section)
        },
        onOpenEvaluationSummary: {
          showSummaryEditor = true
        }
      )
    case .execution:
      StudentExecutionView(
        days: viewModel.executionDays,
        shiftBadgeText: viewModel.planShiftBadgeText
      )
    case .videos:
      StudentVideoGridView(
        videos: viewModel.videos,
        unavailable: viewModel.videosUnavailable,
        viewModel: videoGridViewModel
      )
    case .growth:
      StudentGrowthView(studentID: viewModel.summary.id, viewModel: growthViewModel)
    case .feedback:
      CoachFeedbackHistoryView(
        feedback: viewModel.feedbackItems,
        days: viewModel.plannedDays,
        onCompose: {
          showComposer = true
        }
      )
    }
  }
}

/// Transport-failure fallback for the evaluation strip (Codex review P2):
/// without it a network blip silently hides a live evaluation banner and the
/// page reads as "no evaluation".
@MainActor
@available(iOS 17.0, macOS 14.0, *)
private struct EvaluationLoadFailureStrip: View {
  let onRetry: () -> Void

  var body: some View {
    Card(accessibilityLabel: "评估状态加载失败") {
      HStack(spacing: MeetPRSpacing.sm) {
        Text("评估状态加载失败")
          .font(Font.MeetPR.footnote)
          .foregroundStyle(Color.MeetPR.fgSecondary)
        Spacer()
        SecondaryButton("重试") {
          onRetry()
        }
      }
    }
  }
}

/// fullScreenCover on iOS / sheet on macOS for the adaptation-week planning
/// entry (spec 033 §7).
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
