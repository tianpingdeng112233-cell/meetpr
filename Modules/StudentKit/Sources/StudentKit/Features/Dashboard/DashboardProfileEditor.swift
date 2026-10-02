import CoreModels
import DesignSystem
import RepositoryContracts
import SwiftUI

/// Hosts the existing profile editor inside Today's navigation stack.
@available(iOS 17.0, macOS 14.0, *)
struct DashboardProfileEditor: View {
  let kind: ProfileCardKind
  let studentID: UUID
  @State private var viewModel: MyProfileViewModel

  init(kind: ProfileCardKind, studentID: UUID, onboarding: any OnboardingRepository) {
    self.kind = kind
    self.studentID = studentID
    self._viewModel = State(
      initialValue: MyProfileViewModel(studentId: studentID, repo: onboarding)
    )
  }

  var body: some View {
    Group {
      switch viewModel.state {
      case .idle, .loading:
        ProgressView()
      case .loaded(let profile):
        ProfileCardEditView(kind: kind, profile: profile, viewModel: viewModel)
      case .empty:
        ProfileCardEditView(
          kind: kind,
          profile: OnboardingProfile(userId: studentID, createdAt: Date(), updatedAt: Date()),
          viewModel: viewModel
        )
      case .failed:
        Button(StudentStrings.localized(.dashboardTodayScreen009)) {
          Task { await viewModel.reload() }
        }
        .buttonStyle(PressScaleButtonStyle())
      }
    }
    .navigationTitle(kind.title)
    .task { await viewModel.loadIfNeeded() }
  }
}
