import CoreModels
import DesignSystem
import RepositoryContracts
import SwiftUI

/// Repositories the evaluation-period page composes (spec 033 §11): the
/// training entry pushes the full TodayWorkoutView, messages push the
/// feedback inbox.
public struct EvaluationPeriodDependencies {
  public let evaluations: any EvaluationRepository
  public let plans: any StudentPlanRepository
  public let logs: any StudentTrainingLogRepository
  public let feedback: any StudentFeedbackRepository
  public let e1rm: any E1RMRepository
  public let readiness: any ReadinessRepository
  public let onboarding: any OnboardingProfileReading

  public init(
    evaluations: any EvaluationRepository,
    plans: any StudentPlanRepository,
    logs: any StudentTrainingLogRepository,
    feedback: any StudentFeedbackRepository,
    e1rm: any E1RMRepository,
    readiness: any ReadinessRepository,
    onboarding: any OnboardingProfileReading = InMemoryOnboardingRepository(studentId: UUID())
  ) {
    self.evaluations = evaluations
    self.plans = plans
    self.logs = logs
    self.feedback = feedback
    self.e1rm = e1rm
    self.readiness = readiness
    self.onboarding = onboarding
  }
}

/// The single-page evaluation-period state (spec 033 §11, D6): replaces the
/// 5 tabs while the coach evaluates. Completion is discovered on appear /
/// foreground refresh and converges through `onCompleted`.
@available(iOS 17.0, macOS 14.0, *)
public struct EvaluationPeriodView: View {
  @State private var viewModel: EvaluationPeriodViewModel
  @State private var feedbackViewModel: FeedbackInboxViewModel
  private let studentID: UUID
  private let dependencies: EvaluationPeriodDependencies
  /// The page replaces the 5 tabs for the whole evaluation window, so it
  /// needs its own way back to login. nil hides the affordance (demo).
  private let onLogout: (@MainActor () async -> Void)?
  @Environment(\.scenePhase) private var scenePhase

  public init(
    studentID: UUID,
    dependencies: EvaluationPeriodDependencies,
    onLogout: (@MainActor () async -> Void)? = nil,
    onCompleted: @escaping @MainActor () async -> Void
  ) {
    self.studentID = studentID
    self.dependencies = dependencies
    self.onLogout = onLogout
    _viewModel = State(
      initialValue: EvaluationPeriodViewModel(
        studentID: studentID,
        evaluations: dependencies.evaluations,
        plans: dependencies.plans,
        feedback: dependencies.feedback,
        onCompleted: onCompleted
      )
    )
    _feedbackViewModel = State(
      initialValue: FeedbackInboxViewModel(repository: dependencies.feedback)
    )
  }

  public var body: some View {
    NavigationStack {
      content
        .background(Color.MeetPR.bg)
        .navigationTitle("评估进行中")
        .toolbar {
          if let onLogout {
            ToolbarItem(placement: .primaryAction) {
              Button {
                Task { await onLogout() }
              } label: {
                Image(systemName: "rectangle.portrait.and.arrow.right")
              }
              .accessibilityLabel("退出登录")
            }
          }
        }
    }
    .task {
      await viewModel.refresh()
    }
    .onChange(of: scenePhase) { _, newPhase in
      // Foreground return is the V0.1b "push": the coach may have
      // completed the evaluation meanwhile.
      guard newPhase == .active else { return }
      Task { await viewModel.refresh() }
    }
  }

  @ViewBuilder
  private var content: some View {
    switch viewModel.state {
    case .loading:
      ProgressView()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    case .failed:
      VStack(spacing: MeetPRSpacing.lg) {
        Text("无法获取评估状态")
          .font(Font.MeetPR.title2)
          .foregroundStyle(Color.MeetPR.fgPrimary)
        PrimaryButton("重试") {
          Task { await viewModel.refresh() }
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .padding(MeetPRSpacing.base)
    case .active:
      activeContent
    }
  }

  private var activeContent: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: MeetPRSpacing.base) {
        countdownCard
        messagesCard
        adaptationCard
      }
      .padding(MeetPRSpacing.base)
    }
    .refreshable {
      await viewModel.refresh()
    }
  }

  private var countdownCard: some View {
    TimelineView(.everyMinute) { context in
      Card(accessibilityLabel: "评估倒计时") {
        VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
          Text("教练正在评估你")
            .font(Font.MeetPR.title2)
            .foregroundStyle(Color.MeetPR.fgPrimary)
          Text(viewModel.countdownText(now: context.date))
            .font(Font.MeetPR.body)
            .foregroundStyle(Color.MeetPR.fgSecondary)
          ProgressView(value: viewModel.progress(now: context.date))
            .tint(Color.MeetPR.green)
        }
      }
    }
  }

  private var messagesCard: some View {
    Card(accessibilityLabel: "教练留言") {
      VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
        Eyebrow("教练留言")
        if viewModel.latestMessages.isEmpty {
          Text("教练暂时没有留言")
            .font(Font.MeetPR.footnote)
            .foregroundStyle(Color.MeetPR.fgTertiary)
        } else {
          ForEach(viewModel.latestMessages) { message in
            Text(message.text)
              .font(Font.MeetPR.body)
              .foregroundStyle(Color.MeetPR.fgPrimary)
              .lineLimit(2)
          }
          NavigationLink {
            FeedbackInboxView(studentID: studentID, viewModel: feedbackViewModel)
          } label: {
            Text("查看全部留言")
              .font(Font.MeetPR.footnote)
              .foregroundStyle(Color.MeetPR.brandRed)
          }
        }
      }
    }
  }

  private var adaptationCard: some View {
    Card(accessibilityLabel: "适应周训练") {
      VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
        Eyebrow("适应周训练(本周)")
        if viewModel.hasAdaptationTraining {
          adaptationDaysSummary
          NavigationLink {
            TodayWorkoutView(
              studentID: studentID,
              plans: dependencies.plans,
              logs: dependencies.logs,
              e1rm: dependencies.e1rm,
              onboarding: dependencies.onboarding,
              readiness: dependencies.readiness
            )
          } label: {
            Text("开始训练")
              .font(Font.MeetPR.headline)
              .foregroundStyle(.white)
              .frame(maxWidth: .infinity)
              .padding()
              .background(Color.MeetPR.brandRed)
              .clipShape(.rect(cornerRadius: 12))
          }
        } else {
          Text("教练正在为你准备适应周训练")
            .font(Font.MeetPR.footnote)
            .foregroundStyle(Color.MeetPR.fgTertiary)
        }
      }
    }
  }

  @ViewBuilder
  private var adaptationDaysSummary: some View {
    if let plan = viewModel.adaptationPlan {
      let trainingDays = plan.days.filter { !$0.exercises.isEmpty }
      ForEach(trainingDays.prefix(4)) { day in
        Text(daySummary(day))
          .font(Font.MeetPR.footnote)
          .foregroundStyle(Color.MeetPR.fgSecondary)
      }
    }
  }

  private func daySummary(_ day: StudentPlanDay) -> String {
    let weekday = StudentFormatting.weekdayFormatter.string(from: day.date)
    let names = day.exercises.prefix(3).map(\.exercise.name).joined(separator: "·")
    return "\(weekday): \(names)"
  }
}
