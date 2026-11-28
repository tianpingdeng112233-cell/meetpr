#if DEMO_MODE && DEMO_USER_STUDENT
  import AppShell
  import ChatUI
  import CoreModels
  import RepositoryContracts
  import StudentKit
  import SwiftUI

  /// Mount the usual student tabs with a completed profile and a pre-existing coach conversation.
  /// The seed already contains the rebuilt history, including the previous cycle's imported lifts.
  @MainActor
  struct DemoShowcaseScreen: View {
    let session: Session
    let chat: InMemoryChatRepository
    let controller: ChatSessionController
    let scene: DemoShowcase
    let plans: InMemoryStudentPlanRepository
    let logs: InMemoryStudentTrainingLogRepository
    let feedback: InMemoryStudentFeedbackRepository
    let markers: InMemoryVideoMarkerRepository
    let readiness: InMemoryReadinessRepository
    let estimates: InMemoryE1RMRepository
    let onboarding: InMemoryOnboardingRepository
    let videos: VideoUploadServices

    init(scene: DemoShowcase) {
      self.scene = scene
      let conversation = DemoShowcaseConversation(scene: scene)
      let controller = ChatSessionController()
      self.controller = controller
      session = Session(
        auth: DemoAuthRepository(user: scene.user), tokenStore: DemoTokenStore(user: scene.user)
      ) {
        await controller.cancelAllAndWaitForCleanup()
      }
      chat = InMemoryChatRepository(currentUserID: scene.user.id, seed: conversation.chat)
      plans = InMemoryStudentPlanRepository(
        store: InMemoryPlanStore(seed: [scene.user.id: scene.plan]))
      logs = InMemoryStudentTrainingLogRepository(seed: scene.logs)
      readiness = InMemoryReadinessRepository(seed: [
        ReadinessCheckin(
          id: DemoShowcase.id(9), studentId: scene.user.id,
          checkinDate: DemoShowcase.dayString(scene.today), sleepQuality: 4, mood: 4,
          stress: 3, muscleFatigue: [], submittedAt: scene.today)
      ])
      estimates = InMemoryE1RMRepository(seedPoints: scene.points, seedPRs: scene.records)
      onboarding = InMemoryOnboardingRepository(
        seed: scene.profile, bodyWeightsByDay: scene.bodyWeights)
      var urls: [UUID: URL] = [:]
      for video in conversation.videos { urls[video.id] = scene.videoURL }
      feedback = InMemoryStudentFeedbackRepository(seed: conversation.feedback, playbackURLs: urls)
      markers = InMemoryVideoMarkerRepository(
        seed: conversation.markers, coachID: DemoShowcase.coachID)
      videos = VideoUploadServices(
        manager: VideoUploadServices.demo().manager,
        replayRepository: DemoShowcaseReplay(videos: conversation.videos, url: scene.videoURL))
    }

    var body: some View {
      Group {
        if let context = controller.context {
          StudentRootView(
            studentID: scene.user.id, loginIdentifier: scene.user.name ?? scene.user.phone,
            plans: plans, logs: logs, feedback: feedback, videoMarkers: markers, e1rm: estimates,
            readiness: readiness,
            videoUploads: videos, onboarding: onboarding, onLogout: { await session.logout() },
            account: InMemoryAccountRepository(),
            restTimerActivityController: RestTimerLiveActivityController.shared,
            allowsChat: true, chat: chat, currentUserID: scene.user.id, inbox: context.inbox,
            sendCoordinator: context.sendCoordinator,
            activeCoach: ActiveCoachContext(
              coachID: scene.binding.coachId, coachDisplayName: DemoShowcase.coachName))
        } else {
          ProgressView()
        }
      }
      .task {
        await controller.activateStudent(
          repository: chat, currentUserID: scene.user.id,
          activeCoachID: DemoShowcase.coachID, refreshBinding: {})
      }
    }
  }
#endif
