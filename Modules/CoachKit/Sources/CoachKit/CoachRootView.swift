import DesignSystem
import RepositoryContracts
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
public struct CoachRootView: View {
  private let repository: any PlanRepository
  private let studentPlans: any StudentPlanRepository
  private let studentLogs: any StudentTrainingLogRepository
  private let feedback: any StudentFeedbackRepository
  private let inviteCodes: any InviteCodeRepository
  private let studentVideos: any CoachStudentVideoRepository
  private let readiness: any ReadinessRepository
  private let familyMapProvider: (any CoachPlanFamilyMapProviding)?
  private let draftStore: DraftStore
  @State private var rosterViewModel: StudentRosterViewModel
  @State private var profileViewModel: CoachMyProfileViewModel

  @MainActor
  public init(
    repository: any PlanRepository = InMemoryPlanRepository.preview(),
    studentPlans: any StudentPlanRepository = EmptyStudentPlanRepository(),
    studentLogs: any StudentTrainingLogRepository = EmptyStudentTrainingLogRepository(),
    feedback: any StudentFeedbackRepository = EmptyStudentFeedbackRepository(),
    inviteCodes: (any InviteCodeRepository)? = nil,
    studentVideos: any CoachStudentVideoRepository = InMemoryCoachStudentVideoRepository(),
    readiness: any ReadinessRepository = EmptyReadinessRepository(),
    familyMapProvider: (any CoachPlanFamilyMapProviding)? = nil,
    onLogout: @escaping @MainActor () async -> Void = {},
    draftStore: DraftStore = DraftStore.shared
  ) {
    self.repository = repository
    self.studentPlans = studentPlans
    self.studentLogs = studentLogs
    self.feedback = feedback
    self.inviteCodes = inviteCodes ?? InMemoryInviteCodeRepository()
    self.studentVideos = studentVideos
    self.readiness = readiness
    self.familyMapProvider = familyMapProvider
    self.draftStore = draftStore
    _rosterViewModel = State(
      initialValue: StudentRosterViewModel(
        students: repository,
        plans: studentPlans,
        trainingLogs: studentLogs,
        feedback: feedback
      )
    )
    _profileViewModel = State(
      initialValue: CoachMyProfileViewModel(logoutAction: onLogout)
    )
  }

  public var body: some View {
    TabView {
      CoachPlanningHomeView(repository: repository, draftStore: draftStore)
        .tabItem {
          Label("排计划", systemImage: "calendar.badge.plus")
        }

      StudentRosterView(
        viewModel: rosterViewModel,
        plans: studentPlans,
        trainingLogs: studentLogs,
        feedback: feedback,
        videos: studentVideos,
        familyMapProvider: familyMapProvider,
        readiness: readiness
      )
      .tabItem {
        Label("学员", systemImage: "person.2")
      }
      .badge(rosterViewModel.pendingAttentionCount)

      CoachMyProfileView(viewModel: profileViewModel, inviteCodes: inviteCodes)
        .tabItem {
          Label("我的", systemImage: "person")
        }
    }
    .task {
      await rosterViewModel.loadIfNeeded()
    }
  }
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
private struct CoachPlanningHomeView: View {
  let repository: any PlanRepository
  let draftStore: DraftStore
  @State private var showPlanning = false

  var body: some View {
    NavigationStack {
      VStack(alignment: .leading, spacing: MeetPRSpacing.lg) {
        Text("教练端")
          .font(Font.MeetPR.title1)
          .foregroundStyle(Color.MeetPR.fgPrimary)

        PrimaryButton("排新计划", isFullWidth: true) {
          showPlanning = true
        }
      }
      .padding(MeetPRSpacing.base)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .background(Color.MeetPR.bg)
      .navigationTitle("MeetPR")
    }
    #if os(iOS)
      .fullScreenCover(isPresented: $showPlanning) {
        PlanningCoordinatorView(
          repository: repository,
          draftStore: draftStore
        )
      }
    #else
      .sheet(isPresented: $showPlanning) {
        PlanningCoordinatorView(
          repository: repository,
          draftStore: draftStore
        )
      }
    #endif
  }
}
