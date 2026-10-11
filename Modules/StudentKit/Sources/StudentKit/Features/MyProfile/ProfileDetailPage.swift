import CoreModels
import DesignSystem
import SwiftUI

struct ProfilePage<Content: View>: View {
  let title: String
  @ViewBuilder let content: () -> Content

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: MeetPRSpacing.space4, content: content)
        .padding(MeetPRSpacing.pageHorizontal)
    }
    .background(Color.MeetPR.bgBase)
    .navigationTitle(title)
    #if os(iOS)
      .toolbar(.visible, for: .navigationBar)
      .navigationBarTitleDisplayMode(.inline)
    #endif
  }
}

struct ProfileDetailPage: View {
  let destination: ProfileMenuDestination
  let viewModel: MyProfileViewModel
  let readiness: ReadinessCheckin?
  let onReadiness: () -> Void
  @State private var editor: ProfileCardKind?

  var body: some View {
    ProfilePage(title: destination.title) {
      if let profile = viewModel.state.profile {
        ProfileDetailRows(
          destination: destination, profile: profile, readiness: readiness,
          onEdit: { editor = $0 }, onReadiness: onReadiness)
      } else {
        ProfileLoadingStatus(viewModel: viewModel)
      }
      if viewModel.state.profile != nil, viewModel.isFailed {
        ProfileLoadingStatus(viewModel: viewModel)
      }
    }
    .navigationDestination(item: $editor) { kind in
      ProfileEditorDestination(kind: kind, viewModel: viewModel)
    }
    .refreshable { await viewModel.reload() }
  }
}

struct ProfileDetailRows: View {
  let destination: ProfileMenuDestination
  let profile: OnboardingProfile
  let readiness: ReadinessCheckin?
  let onEdit: (ProfileCardKind) -> Void
  let onReadiness: () -> Void

  var body: some View {
    let summary = MyProfileV3Presentation.make(
      profile: profile, readiness: readiness, restTimer: .automatic)
    MyProfileGroupCard {
      if destination == .about {
        row(
          .basics, title: StudentStrings.localized(.profileCardsSection002),
          value: summary.heightAndWeight)
        MyProfileDivider()
        row(
          .background, title: StudentStrings.localized(.myProfileView011),
          value: summary.trainingBackground)
        MyProfileDivider()
        row(
          .environment, title: StudentStrings.localized(.myProfileView012),
          value: summary.trainingEnvironment)
        MyProfileDivider()
        row(
          .materials, title: StudentStrings.localized(.myProfileView007),
          value: summary.muscleGroups)
      } else {
        Button(action: onReadiness) {
          MyProfileValueRow(
            label: StudentStrings.localized(.myProfileView004),
            value: summary.recoveryChips.isEmpty
              ? StudentStrings.localized(.myProfileV3Presentation010)
              : summary.recoveryChips.joined(separator: " · "))
        }
        MyProfileDivider()
        row(
          .injuries, title: StudentStrings.localized(.myProfileView005),
          value: summary.injuryChips.joined(separator: " · "))
      }
    }
    .buttonStyle(.plain)
  }

  private func row(_ kind: ProfileCardKind, title: String, value: String) -> some View {
    Button {
      onEdit(kind)
    } label: {
      MyProfileValueRow(label: title, value: value)
    }
  }
}

struct ProfileEditorDestination: View {
  let kind: ProfileCardKind
  let viewModel: MyProfileViewModel

  var body: some View {
    Group {
      if let profile = viewModel.state.profile {
        ProfileCardEditView(kind: kind, profile: profile, viewModel: viewModel)
      } else {
        ProfileLoadingStatus(viewModel: viewModel)
      }
    }
    .navigationTitle(kind.title)
    #if os(iOS)
      .toolbar(.visible, for: .navigationBar)
      .navigationBarTitleDisplayMode(.inline)
    #endif
  }
}

struct ProfileLoadingStatus: View {
  let viewModel: MyProfileViewModel

  var body: some View {
    if viewModel.isFailed {
      Button(StudentStrings.localized(.myProfileView002)) {
        Task { await viewModel.reload() }
      }
      .foregroundStyle(Color.MeetPR.textMuted)
      .frame(minHeight: MeetPRSpacing.minimumHitTarget)
    } else if viewModel.state == .empty {
      MyProfileStateCard(text: StudentStrings.localized(.myProfileView001))
    } else {
      ProgressView().frame(maxWidth: .infinity)
    }
  }
}
