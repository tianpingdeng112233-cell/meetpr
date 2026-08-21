// swiftlint:disable file_length
import CoreModels
import DesignSystem
import Foundation
import RepositoryContracts
import SwiftUI

/// Coach 编排 tab landing, reskinned to the house style (custom heavy large title
/// + hidden nav bar, brand-red CTA, mono-labelled sections). The `DKCoachPlanningEditor`
/// mock it descends from depicts the *in-wizard* cycle editor (a separate, later task);
/// this screen is the planning home that launches that wizard. It binds verbatim to
/// `PlanningWorkspaceViewModel` (drafts / needs-planning / recent-published) and keeps
/// the fullScreenCover-driven `PlanningCoordinatorView` wizard + draft-resume behavior.
@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct CoachPlanningHomeView: View {
  private let context: CoachStudentDetailContext
  private let now: @Sendable () -> Date
  private let chat: CoachChatContext?
  @State private var viewModel: PlanningWorkspaceViewModel
  @State private var showPlanning = false
  @State private var activeIntent: PlanningIntent = .blank
  @State private var isConversationListPresented = false

  init(
    context: CoachStudentDetailContext,
    chat: CoachChatContext? = nil,
    now: @escaping @Sendable () -> Date = { Date() }
  ) {
    self.context = context
    self.chat = chat
    self.now = now
    _viewModel = State(
      initialValue: PlanningWorkspaceViewModel(
        repository: context.planning,
        studentPlans: context.plans,
        draftStore: context.draftStore,
        profiles: context.profiles,
        now: now
      )
    )
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          header

          PrimaryButton(
            PlanningWorkspaceStrings.text("coach.workspace.newPlan"), isFullWidth: true
          ) {
            presentPlanning(intent: .blank)
          }
          .padding(.top, 20)

          importEntry
            .padding(.top, 12)

          workspaceContent
            .padding(.top, 20)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .topLeading)
      }
      .scrollContentBackground(.hidden)
      .background(Color.MeetPR.bg)
      .hideNavigationBar()
      .navigationDestination(isPresented: $isConversationListPresented) {
        if let chat {
          ConversationListView(chat: chat)
        }
      }
      .refreshable {
        await viewModel.refresh()
      }
    }
    .task {
      await viewModel.loadIfNeeded()
    }
    .onChange(of: showPlanning) { _, isShowing in
      guard !isShowing else { return }
      Task { await viewModel.refresh() }
    }
    .modifier(
      PlanningWorkspacePresenter(isPresented: $showPlanning) {
        PlanningCoordinatorView(
          repository: context.planning,
          draftStore: context.draftStore,
          intent: activeIntent,
          profiles: context.profiles
        )
      })
  }

  // MARK: - Header

  private var header: some View {
    HStack(alignment: .top, spacing: MeetPRSpacing.md) {
      VStack(alignment: .leading, spacing: MeetPRSpacing.xs) {
        Eyebrow(PlanningWorkspaceStrings.text("coach.workspace.eyebrow"))
        Text(PlanningWorkspaceStrings.text("coach.workspace.title"))
          .font(.system(size: 36, weight: .heavy))
          .foregroundStyle(Color.MeetPR.fgPrimary)
        Text(PlanningWorkspaceStrings.text("coach.workspace.subtitle"))
          .font(.system(size: 14))
          .foregroundStyle(Color.MeetPR.fgSecondary)
      }
      Spacer(minLength: MeetPRSpacing.sm)
      CoachChatHeaderButton(chat: chat) {
        isConversationListPresented = true
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  // MARK: - Import entry (spec 043 — frozen, greyed out; see PlanImportCapability)

  @ViewBuilder
  private var importEntry: some View {
    ImportEntryButton(
      repository: context.planning,
      now: now,
      onPublished: { Task { await viewModel.refresh() } }
    )
  }

  // MARK: - Workspace body

  @ViewBuilder
  private var workspaceContent: some View {
    switch viewModel.state {
    case .idle, .loading:
      ProgressView()
        .frame(maxWidth: .infinity)
        .padding(.top, MeetPRSpacing.lg)
    case .failed(let message):
      PlanningWorkspaceFailure(message: message) {
        Task { await viewModel.refresh() }
      }
    case .loaded:
      if viewModel.hasWorkspaceContent {
        loadedSections
      } else {
        emptyState
      }
    }
  }

  private var loadedSections: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.lg) {
      if !viewModel.draftRows.isEmpty {
        PlanningDraftSection(rows: viewModel.draftRows) { row in
          presentPlanning(intent: .firstRegularPlan(row.student, nil))
        }
      }

      if !viewModel.needsPlanningRows.isEmpty {
        PlanningNeedsSection(rows: viewModel.needsPlanningRows) { row in
          presentPlanning(intent: .firstRegularPlan(row.student, row.profile))
        }
      }

      if !viewModel.recentPublishedRows.isEmpty {
        PlanningRecentPublishedSection(rows: viewModel.recentPublishedRows, context: context)
      }
    }
  }

  // MARK: - Empty state

  private var emptyState: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
      Text(PlanningWorkspaceStrings.text("coach.workspace.empty.title"))
        .font(Font.MeetPR.monoLabel)
        .tracking(Font.MeetPR.monoLabelTracking)
        .foregroundStyle(Color.MeetPR.brandRed)
      Text(PlanningWorkspaceStrings.text("coach.workspace.empty.body"))
        .font(.system(size: 14))
        .foregroundStyle(Color.MeetPR.fgSecondary)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(16)
    .background(Color.MeetPR.surface1)
    .clipShape(.rect(cornerRadius: 12))
    .overlay {
      RoundedRectangle(cornerRadius: 12).stroke(Color.MeetPR.border, lineWidth: 1)
    }
  }

  private func presentPlanning(intent: PlanningIntent) {
    activeIntent = intent
    showPlanning = true
  }
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
private struct PlanningWorkspaceFailure: View {
  let message: String
  let onRetry: () -> Void

  var body: some View {
    Card(accessibilityLabel: PlanningWorkspaceStrings.text("coach.workspace.error.accessibility")) {
      HStack(spacing: MeetPRSpacing.base) {
        Label(message, systemImage: "exclamationmark.triangle")
          .font(Font.MeetPR.footnote)
          .foregroundStyle(Color.MeetPR.amber)
        Spacer()
        SecondaryButton(PlanningWorkspaceStrings.text("coach.common.retry")) {
          onRetry()
        }
      }
    }
  }
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
private struct PlanningWorkspacePresenter<PresentedContent: View>: ViewModifier {
  @Binding var isPresented: Bool
  private let presentedContent: PresentedContent

  init(
    isPresented: Binding<Bool>,
    @ViewBuilder content: () -> PresentedContent
  ) {
    _isPresented = isPresented
    presentedContent = content()
  }

  func body(content base: Content) -> some View {
    #if os(iOS)
      base.fullScreenCover(isPresented: $isPresented) {
        presentedContent
      }
    #else
      base.sheet(isPresented: $isPresented) {
        presentedContent
      }
    #endif
  }
}

#if DEBUG
  @MainActor
  @available(iOS 17.0, macOS 14.0, *)
  private enum PlanningWorkspacePreviewSeed {
    static let now = Date(timeIntervalSince1970: 1_797_552_000)

    static func seededContext() -> CoachStudentDetailContext {
      makeContext(students: students(), plans: seededPlans(), draft: draft())
    }

    static func emptyContext() -> CoachStudentDetailContext {
      makeContext(students: [], plans: [:], draft: nil)
    }

    private static func makeContext(
      students: [CoachStudentSummary],
      plans: [UUID: StudentPlanView],
      draft: DraftTrainingPlan?
    ) -> CoachStudentDetailContext {
      let planRepository = InMemoryPlanRepository(students: students, catalog: [exercise()])
      let planReader = PlanningWorkspacePreviewPlanRepository(plans: plans)
      return CoachStudentDetailContext(
        plans: planReader,
        trainingLogs: EmptyStudentTrainingLogRepository(),
        feedback: EmptyStudentFeedbackRepository(),
        evaluations: InMemoryCoachEvaluationRepository(),
        summaries: InMemoryCoachEvaluationSummaryRepository(coachId: uuid(90)),
        profiles: InMemoryCoachStudentProfileReader(profiles: profiles()),
        videos: InMemoryCoachStudentVideoRepository(),
        readiness: EmptyReadinessRepository(),
        exerciseStats: InMemoryCoachExerciseStatsRepository(),
        planning: planRepository,
        draftStore: makeStore(draft: draft)
      )
    }

    private static func students() -> [CoachStudentSummary] {
      [
        CoachStudentSummary(id: uuid(1), displayName: "王五", status: .active),
        CoachStudentSummary(id: uuid(2), displayName: "张三", status: .active),
        CoachStudentSummary(id: uuid(3), displayName: "赵六", status: .active),
        CoachStudentSummary(id: uuid(4), displayName: "李四", status: .active),
      ]
    }

    private static func seededPlans() -> [UUID: StudentPlanView] {
      [
        uuid(2): plan(startOffset: -20, weeks: 3, kind: .regular),
        uuid(4): plan(startOffset: -4, weeks: 4, kind: .regular),
      ]
    }

    private static func draft() -> DraftTrainingPlan {
      DraftTrainingPlan(
        traineeID: uuid(1),
        name: "王五 4 周计划",
        startDate: now,
        endDate: now.addingTimeInterval(27 * 86_400),
        planWeeks: 4,
        currentStepRawValue: PlanningStep.selectAccessories.rawValue,
        lastSavedAt: now.addingTimeInterval(-1_800)
      )
    }

    private static func profiles() -> [OnboardingProfile] {
      [
        OnboardingProfile(
          userId: uuid(2),
          squat1RMKg: 180,
          bench1RMKg: 120,
          deadlift1RMKg: 220,
          trainingDays: [.mon, .wed, .fri],
          gymTier: .commercial,
          createdAt: now,
          updatedAt: now
        )
      ]
    }

    private static func plan(
      startOffset: Int,
      weeks: Int,
      kind: PlanKind
    ) -> StudentPlanView {
      let startDate = now.addingTimeInterval(Double(startOffset) * 86_400)
      return StudentPlanView(
        cycleID: uuid(UInt8(40 + weeks)),
        weekIndex: 1,
        startDate: startDate,
        planKind: kind,
        days: (0..<(weeks * 7)).map { offset in
          StudentPlanDay(
            id: uuid(UInt8(50 + offset)),
            date: startDate.addingTimeInterval(Double(offset) * 86_400),
            exercises: offset.isMultiple(of: 2) ? [studentExercise()] : []
          )
        }
      )
    }

    private static func studentExercise() -> StudentPlanExercise {
      StudentPlanExercise(
        id: uuid(80),
        exercise: exercise(),
        sequenceIndex: 0,
        prescribedSets: [PrescribedSet(id: uuid(81), setIndex: 0, weightKg: 140, reps: 5)]
      )
    }

    private static func exercise() -> Exercise {
      Exercise(
        id: uuid(70),
        name: "深蹲",
        nameEn: "Squat",
        exerciseType: .mainLift,
        mainLiftFamily: .squat,
        isCompetitionLift: true,
        muscleGroups: [.quad, .glute],
        equipment: [.barbell],
        movementPattern: [.squat],
        createdAt: now
      )
    }

    private static func makeStore(draft: DraftTrainingPlan?) -> DraftStore {
      do {
        let store = try DraftStore.inMemory()
        if let draft {
          try store.saveDraft(draft)
        }
        return store
      } catch {
        fatalError("Unable to create preview draft store: \(error)")
      }
    }

    private static func uuid(_ byte: UInt8) -> UUID {
      UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 3, byte))
    }
  }

  @available(iOS 17.0, macOS 14.0, *)
  private actor PlanningWorkspacePreviewPlanRepository: StudentPlanRepository {
    let plans: [UUID: StudentPlanView]

    init(plans: [UUID: StudentPlanView]) {
      self.plans = plans
    }

    func fetchCurrentPlan(studentID: UUID) async throws -> StudentPlanView? {
      plans[studentID]
    }

    func fetchDay(studentID: UUID, date: Date) async throws -> StudentPlanDay? {
      plans[studentID]?.days.first {
        CoachFeatureCalendar.isSameDay($0.date, date)
      }
    }

    func fetchCycleDays(studentID: UUID) async throws -> [StudentPlanDay] {
      plans[studentID]?.days ?? []
    }
  }

  #Preview("Planning Workspace Seeded") {
    let fixedNow = Date(timeIntervalSince1970: 1_797_552_000)
    CoachPlanningHomeView(
      context: PlanningWorkspacePreviewSeed.seededContext(),
      now: { fixedNow }
    )
  }

  #Preview("Planning Workspace Empty") {
    let fixedNow = Date(timeIntervalSince1970: 1_797_552_000)
    CoachPlanningHomeView(
      context: PlanningWorkspacePreviewSeed.emptyContext(),
      now: { fixedNow }
    )
  }
#endif
