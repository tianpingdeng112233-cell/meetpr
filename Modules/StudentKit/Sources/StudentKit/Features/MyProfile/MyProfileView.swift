import CoreModels
import DesignSystem
import RepositoryContracts
import SwiftUI

/// Student profile hub. Existing onboarding, readiness, preferences,
/// account, export, and logout flows remain the only mutation paths.
@available(iOS 17.0, macOS 14.0, *)
public struct MyProfileView: View {
  private let identity: ProfileIdentity
  private let onNavigationChanged: (Bool) -> Void
  private let studentID: UUID
  private let plans: any StudentPlanRepository
  private let e1rm: any E1RMRepository
  private let onboarding: any OnboardingRepository
  private let onLogout: (@MainActor () async -> Void)?
  private let account: (any AccountRepository)?
  private let logs: (any StudentTrainingLogRepository)?
  private let restTimerSettings: any StudentRestTimerSettingsStoring
  private let trainingReminderServices: TrainingReminderServices
  private let notifications: StudentNotificationsCoordinator?
  private let onOpenPlanNotification: () -> Void

  @State private var path: [ProfileMenuDestination] = []
  @State private var viewModel: MyProfileViewModel
  @State private var readinessViewModel: ReadinessCheckinViewModel
  @State private var showsOneRMInfo = false
  @State private var showsReadiness = false
  @State private var showingNotifications = false
  @State private var conversationID: UUID?

  public init(
    studentID: UUID,
    loginIdentifier: String = "",
    activeCoach: ActiveCoachContext? = nil,
    onNavigationChanged: @escaping (Bool) -> Void = { _ in },
    plans: any StudentPlanRepository,
    e1rm: any E1RMRepository,
    onboarding: any OnboardingRepository,
    readiness: any ReadinessRepository = InMemoryReadinessRepository(),
    onLogout: (@MainActor () async -> Void)? = nil,
    account: (any AccountRepository)? = nil,
    logs: (any StudentTrainingLogRepository)? = nil,
    restTimerSettings: any StudentRestTimerSettingsStoring =
      UserDefaultsRestTimerSettingsStore(),
    notifications: StudentNotificationsCoordinator? = nil,
    onOpenPlanNotification: @escaping () -> Void = {}
  ) {
    self.identity = ProfileIdentity(loginIdentifier: loginIdentifier, activeCoach: activeCoach)
    self.onNavigationChanged = onNavigationChanged
    self.studentID = studentID
    self.plans = plans
    self.e1rm = e1rm
    self.onboarding = onboarding
    self.onLogout = onLogout
    self.account = account
    self.logs = logs
    self.restTimerSettings = restTimerSettings
    self.trainingReminderServices = .live
    self.notifications = notifications
    self.onOpenPlanNotification = onOpenPlanNotification
    self._viewModel = State(
      initialValue: MyProfileViewModel(studentId: studentID, repo: onboarding)
    )
    self._readinessViewModel = State(
      initialValue: ReadinessCheckinViewModel(repo: readiness)
    )
  }

  public var body: some View {
    NavigationStack(path: $path) {
      ScrollView {
        VStack(alignment: .leading, spacing: MeetPRSpacing.point14) {
          MyProfileHeader(
            showsChat: notifications != nil,
            unreadCount: notifications?.totalUnreadCount ?? 0,
            onOpenChat: { showingNotifications = true }
          )
          ProfileHomeContent(
            identity: identity, state: viewModel.state, isFailed: viewModel.isFailed,
            onOpen: { path.append($0) },
            onRetry: { Task { await viewModel.reload() } },
            onOneRMInfo: { showsOneRMInfo = true })
        }
        .padding(.horizontal, MeetPRSpacing.pageHorizontal)
        .padding(.top, MeetPRSpacing.point6)
        .padding(.bottom, MeetPRSpacing.point28)
      }
      .scrollIndicators(.hidden)
      .scrollContentBackground(.hidden)
      .background(Color.MeetPR.bgBase)
      .hideNavigationBar()
      .navigationDestination(for: ProfileMenuDestination.self) { destination in
        destinationView(destination)
      }
      .modifier(
        OptionalStudentNotificationHostModifier(
          coordinator: notifications,
          showsNotifications: $showingNotifications,
          conversationID: $conversationID,
          onOpenPlan: onOpenPlanNotification
        )
      )
      .refreshable {
        await viewModel.reload()
        await readinessViewModel.load(studentId: studentID)
      }
    }
    .background(Color.MeetPR.bgBase)
    .onChange(of: path) { _, newPath in onNavigationChanged(!newPath.isEmpty) }
    .alert(StudentStrings.localized(.myProfileView019), isPresented: $showsOneRMInfo) {
      Button(StudentStrings.acknowledge, role: .cancel) {}
    } message: {
      Text(StudentStrings.localized(.myProfileView020))
    }
    .task {
      await viewModel.loadIfNeeded()
      await readinessViewModel.load(studentId: studentID)
    }
    .sheet(isPresented: $showsReadiness) {
      ReadinessCheckinSheet(
        studentID: studentID,
        viewModel: readinessViewModel,
        prefill: currentReadiness,
        onClose: { showsReadiness = false }
      )
      .presentationDetents([.large])
    }
  }

  @ViewBuilder
  private func destinationView(_ destination: ProfileMenuDestination) -> some View {
    if let kind = destination.editor {
      ProfileEditorDestination(kind: kind, viewModel: viewModel)
    } else if destination == .settings {
      ProfilePage(title: destination.title) {
        MyProfileFallbackRows(
          studentID: studentID, plans: plans, account: account, logs: logs,
          restTimerSettings: restTimerSettings,
          trainingReminderServices: trainingReminderServices, onLogout: onLogout,
          recommendedWeekdays: viewModel.state.profile.map {
            Set($0.trainingDays.map(TrainingReminderWeekday.init))
          })
      }
    } else {
      ProfileDetailPage(
        destination: destination, viewModel: viewModel, readiness: currentReadiness,
        onReadiness: { showsReadiness = true })
    }
  }

  private var currentReadiness: ReadinessCheckin? {
    guard case .done(let checkin) = readinessViewModel.gate else { return nil }
    return checkin
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct MyProfileHeader: View {
  let showsChat: Bool
  let unreadCount: Int
  let onOpenChat: @MainActor () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.point14) {
      HStack(alignment: .top) {
        MeetPRMark.header
          .frame(width: 97, height: 24, alignment: .leading)
        Spacer()
        if showsChat {
          HeaderChatButton(
            unreadCount: unreadCount,
            accessibilityLabel: StudentStrings.localized(.myProfileView015),
            action: onOpenChat
          )
        }
      }
      Text(StudentStrings.localized(.myProfileView016))
        .font(.MeetPR.display(size: MeetPRFontMetrics.size34))
        .foregroundStyle(Color.MeetPR.textPrimary)

    }
  }
}

@available(iOS 17.0, macOS 14.0, *)
struct MyProfileStateCard: View {
  let text: String

  var body: some View {
    Text(text)
      .font(.MeetPR.body(size: MeetPRFontMetrics.size14))
      .foregroundStyle(Color.MeetPR.textMuted)
      .frame(maxWidth: .infinity, minHeight: 120)
      .background(Color.MeetPR.surfaceCard)
      .clipShape(.rect(cornerRadius: MeetPRRadius.card))
  }
}
