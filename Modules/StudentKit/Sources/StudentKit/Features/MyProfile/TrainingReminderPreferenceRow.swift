import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct TrainingReminderPreferenceRow: View {
  @State private var viewModel: TrainingReminderSettingsViewModel

  init(studentID: UUID, services: TrainingReminderServices) {
    self._viewModel = State(
      initialValue: TrainingReminderSettingsViewModel(
        studentID: studentID,
        services: services
      )
    )
  }

  var body: some View {
    NavigationLink {
      TrainingReminderSettingsView(viewModel: viewModel)
    } label: {
      MyProfileValueRow(
        label: StudentStrings.localized(.trainingReminderPreferenceRow001),
        value: TrainingReminderCopy.summary(for: viewModel.settings)
      )
    }
    .buttonStyle(.plain)
    .task {
      await viewModel.synchronize()
    }
  }
}
