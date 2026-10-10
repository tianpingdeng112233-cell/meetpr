import RepositoryContracts
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
struct TrainingReminderPreferenceRow: View {
  @State private var viewModel: TrainingReminderSettingsViewModel

  init(
    studentID: UUID,
    services: TrainingReminderServices,
    plans: any StudentPlanRepository,
    recommendedWeekdays: Set<TrainingReminderWeekday>? = nil
  ) {
    self._viewModel = State(
      initialValue: TrainingReminderSettingsViewModel(
        studentID: studentID,
        services: services,
        recommendedWeekdays: recommendedWeekdays,
        plans: plans
      )
    )
  }

  var body: some View {
    NavigationLink {
      TrainingReminderSettingsView(viewModel: viewModel)
    } label: {
      MyProfileValueRow(
        label: StudentStrings.localized(.trainingReminderPreferenceRow001),
        value: TrainingReminderCopy.summary(for: viewModel.settings), inline: true
      )
    }
    .task {
      await viewModel.synchronize()
    }
  }
}
