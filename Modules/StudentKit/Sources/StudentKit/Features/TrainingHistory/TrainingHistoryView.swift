import Analytics
import CoreModels
import DesignSystem
import Foundation
import RepositoryContracts
import SwiftUI

/// Progress is a menu; each destination owns its charts or statistics.
@available(iOS 17.0, macOS 14.0, *)
public struct TrainingHistoryView: View {
  private let studentID: UUID
  private let importedHistoryRefreshToken: Int
  private let onImportedHistoryRefresh: (@MainActor () async -> Void)?
  private let notifications: StudentNotificationsCoordinator?
  private let onOpenPlanNotification: () -> Void
  private let onOpenToday: () -> Void
  @State private var replay: CompletedVideoReplayModel
  @State private var uploads: VideoAttachmentViewModel
  @State private var model: ProgressDataModel
  @State private var path: [ProgressMenuDestination] = []
  @State private var showsNotifications = false
  @State private var conversationID: UUID?

  public init(
    studentID: UUID,
    plans: any StudentPlanRepository,
    logs: any StudentTrainingLogRepository,
    e1rm: any E1RMRepository,
    onboarding: (any OnboardingProfileReading)? = nil,
    feedbackViewModel: FeedbackInboxViewModel? = nil,
    videoUploads: VideoUploadServices? = nil,
    importedHistoryRefreshToken: Int = 0,
    onImportedHistoryRefresh: (@MainActor () async -> Void)? = nil,
    notifications: StudentNotificationsCoordinator? = nil,
    onOpenPlanNotification: @escaping () -> Void = {},
    onOpenToday: @escaping () -> Void = {}
  ) {
    self.studentID = studentID
    self.importedHistoryRefreshToken = importedHistoryRefreshToken
    self.onImportedHistoryRefresh = onImportedHistoryRefresh
    self.notifications = notifications
    self.onOpenPlanNotification = onOpenPlanNotification
    self.onOpenToday = onOpenToday
    let services = videoUploads ?? .demo()
    self._uploads = State(initialValue: VideoAttachmentViewModel(manager: services.manager))
    self._replay = State(
      initialValue: CompletedVideoReplayModel(services: services, feedback: feedbackViewModel))
    self._model = State(
      initialValue: ProgressDataModel(
        studentID: studentID, plans: plans, logs: logs, e1rm: e1rm,
        onboarding: onboarding, feedback: feedbackViewModel))
  }

  public var body: some View {
    NavigationStack(path: $path) {
      ScrollView {
        VStack(alignment: .leading, spacing: MeetPRSpacing.point14) {
          GrowthScreenHeader(
            showsChat: notifications != nil,
            unreadCount: notifications?.totalUnreadCount ?? 0,
            onOpenChat: { showsNotifications = true })
          ProgressMenuContent(
            values: model.menuValues, isFailed: model.isFailed,
            onOpen: { path.append($0) }, onRetry: { Task { await reload() } })
        }
        .padding(.horizontal, MeetPRSpacing.pageHorizontal)
        .padding(.top, MeetPRSpacing.point6)
        .padding(.bottom, MeetPRSpacing.point28)
      }
      .scrollIndicators(.hidden)
      .background(Color.MeetPR.bgBase)
      .hideNavigationBar()
      .navigationDestination(for: ProgressMenuDestination.self) { destination in
        switch destination {
        case .e1rm:
          ProgressE1RMPage(model: model, onOpenToday: onOpenToday)
        case .history:
          AllHistoryScreen(viewModel: model.history, studentID: studentID)
        case .feedback:
          FeedbackInboxView(studentID: studentID, viewModel: model.feedback)
        case .intensity:
          ProgressIntensityPage(model: model)
        }
      }
      .modifier(
        OptionalStudentNotificationHostModifier(
          coordinator: notifications, showsNotifications: $showsNotifications,
          conversationID: $conversationID, onOpenPlan: onOpenPlanNotification)
      )
      .refreshable { await reload() }
    }
    .environment(replay)
    .environment(uploads)
    .modifier(
      VideoMissingFileHost(
        model: uploads,
        context: missingVideoContext)
    )
    .task { await uploads.start(studentID: studentID) }
    .modifier(CompletedVideoReplayHost(model: replay))
    .background(Color.MeetPR.bgBase)
    .task {
      await model.load()
      Analytics.shared.progressViewed(.e1rm)
      Analytics.shared.progressViewed(.volume)
    }
    .task(id: importedHistoryRefreshToken) {
      guard importedHistoryRefreshToken > 0 else { return }
      await model.load()
    }
  }

  private func missingVideoContext(_ attachment: VideoAttachment) -> String {
    guard case .loaded(let weeks, let logs) = model.history.state,
      let log = logs.first(where: { $0.id == attachment.setLogID }),
      let exercise = weeks.flatMap(\.days).flatMap(\.exercises).first(where: {
        $0.id == log.planExerciseID
      })
    else { return attachment.trainingDate.formatted(date: .abbreviated, time: .omitted) }
    return [
      StudentExerciseName.display(exercise.exercise),
      HistoryEntriesView.setLabel(forZeroBasedIndex: log.setIndex),
      StudentFormatting.result(
        weightKg: log.weightKg, reps: log.reps, rpe: log.rpe, actualRIR: log.actualRIR),
    ].joined(separator: " · ")
  }

  private func reload() async {
    await onImportedHistoryRefresh?()
    await model.load()
  }

  static func completedSessionCount(logs: [StudentSetLog], calendar: Calendar) -> Int {
    GrowthScreenPresentation.historyStats(logs: logs, calendar: calendar).trainingSessionCount
  }
}
