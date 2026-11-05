import CoreModels
import DesignSystem
import RepositoryContracts
import SwiftUI

/// Account lifetime owns the queue, including evaluation and bind-gate screens.
public struct StudentSetSyncHost<Content: View>: View {
  private let studentID: UUID
  private let plans: any StudentPlanRepository
  private let logs: any StudentTrainingLogRepository
  private let videos: VideoUploadManager?
  private let runtime: StudentSetSyncRuntime?
  private let onLogout: @MainActor () async -> Void
  private let content: (@escaping @MainActor () async -> Void) -> Content
  @State private var session: StudentSetSyncSession?
  @State private var loadError: String?

  public init(
    studentID: UUID, plans: any StudentPlanRepository,
    logs: any StudentTrainingLogRepository, videos: VideoUploadServices?,
    onLogout: @escaping @MainActor () async -> Void,
    @ViewBuilder content: @escaping (@escaping @MainActor () async -> Void) -> Content
  ) {
    self.studentID = studentID
    self.plans = plans
    self.logs = logs
    self.videos = videos?.manager
    self.runtime = videos?.completionRuntime
    self.onLogout = onLogout
    self.content = content
  }

  public var body: some View {
    Group {
      if let session {
        content { await session.requestLogout() }
          .environment(session)
          .allowsHitTesting(!session.showsLogout)
          .overlay {
            if session.showsLogout { SetSyncLogoutDialog(session: session) }
          }
      } else if let loadError {
        ContentUnavailableView(loadError, systemImage: "exclamationmark.triangle")
      } else {
        ProgressView()
      }
    }
    .task {
      do {
        if session == nil {
          if let runtime, let videos {
            session = try runtime.session(studentID: studentID, videos: videos, onLogout: onLogout)
          } else {
            session = try StudentSetSyncSession.live(
              studentID: studentID, plans: plans,
              logs: logs, videos: videos, onLogout: onLogout)
          }
        }
        session?.start(network: UploadNetworkMonitor())
      } catch { loadError = error.localizedDescription }
    }
    .onDisappear { session?.stop() }
  }
}

private struct SetSyncLogoutDialog: View {
  let session: StudentSetSyncSession

  var body: some View {
    ZStack {
      Color.MeetPR.modalShadow.ignoresSafeArea()
      VStack(spacing: 0) {
        VStack(spacing: MeetPRSpacing.space3) {
          Text(
            session.queue.pendingSetCount == 1
              ? StudentStrings.localized(.setSyncLogoutOne)
              : StudentStrings.replacing(
                .setSyncLogoutMany, values: ["\(session.queue.pendingSetCount)"])
          )
          .font(.headline).bold()
          Text(StudentStrings.localized(.setSyncLogoutBody))
            .font(.subheadline)
            .foregroundStyle(Color.MeetPR.textSecondary)
        }
        .multilineTextAlignment(.center)
        .padding(MeetPRSpacing.space6)
        Divider()
        Button(action: session.uploadThenLogout) {
          HStack(spacing: MeetPRSpacing.space2) {
            if session.isUploadingForLogout { ProgressView().tint(Color.MeetPR.goldCTA) }
            Text(
              StudentStrings.localized(
                session.isUploadingForLogout ? .setSyncUploading : .setSyncLogoutUpload)
            ).bold()
          }
          .frame(maxWidth: .infinity, minHeight: MeetPRSpacing.completionControlHeight)
        }
        .foregroundStyle(Color.MeetPR.goldCTA)
        .disabled(session.isUploadingForLogout)
        Divider()
        Button(StudentStrings.localized(.setSyncLogoutNow)) {
          Task { await session.logOutNow() }
        }
        .frame(maxWidth: .infinity, minHeight: MeetPRSpacing.completionControlHeight)
        Divider()
        Button(StudentStrings.localized(.addedCancel), action: session.cancelLogout)
          .frame(maxWidth: .infinity, minHeight: MeetPRSpacing.completionControlHeight)
      }
      .foregroundStyle(Color.MeetPR.textPrimary)
      .background(Color.MeetPR.surfaceCard, in: .rect(cornerRadius: MeetPRRadius.modal))
      .padding(.horizontal, MeetPRSpacing.point32)
      .accessibilityAddTraits(.isModal)
    }
    .accessibilityIdentifier("setSync.logout")
  }
}
