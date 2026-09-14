import DesignSystem
import SwiftUI

#if os(iOS)
  import UIKit
#endif

@available(iOS 17.0, macOS 14.0, *)
struct TrainingReminderSettingsView: View {
  @Environment(\.openURL) private var openURL
  @Environment(\.scenePhase) private var scenePhase
  let viewModel: TrainingReminderSettingsViewModel

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: MeetPRSpacing.space5) {
        enableCard
        scheduleSection
        if viewModel.showsPermissionDenied {
          permissionWarning
        }
        if viewModel.showsScheduleFailure {
          scheduleFailureWarning
        }
      }
      .padding(.horizontal, MeetPRSpacing.pageHorizontal)
      .padding(.top, MeetPRSpacing.space4)
      .padding(.bottom, MeetPRSpacing.point32)
    }
    .scrollIndicators(.hidden)
    .background(Color.MeetPR.bgBase)
    .onChange(of: scenePhase) { _, phase in
      guard phase == .active else { return }
      Task { await viewModel.refreshAuthorization() }
    }
    .navigationTitle(StudentStrings.localized(.trainingReminderSettingsView001))
    #if os(iOS)
      .navigationBarTitleDisplayMode(.inline)
      .toolbarBackground(Color.MeetPR.bgBase, for: .navigationBar)
      .toolbarBackground(.visible, for: .navigationBar)
    #endif
  }

  private var enableCard: some View {
    Toggle(isOn: enabledBinding) {
      Text(StudentStrings.localized(.trainingReminderSettingsView002))
        .font(.MeetPR.body(size: MeetPRFontMetrics.size16, weight: .semibold))
        .foregroundStyle(Color.MeetPR.textPrimary)
    }
    .tint(Color.MeetPR.gold500)
    .disabled(viewModel.isChangingAuthorization)
    .padding(MeetPRSpacing.space4)
    .background(Color.MeetPR.surfaceCard)
    .clipShape(.rect(cornerRadius: MeetPRRadius.card))
  }

  private var scheduleSection: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.space2) {
      Text(StudentStrings.localized(.trainingReminderSettingsView003))
        .font(.MeetPR.body(size: MeetPRFontMetrics.size12, weight: .semibold))
        .foregroundStyle(Color.MeetPR.textMuted)

      VStack(alignment: .leading, spacing: MeetPRSpacing.space4) {
        Text(StudentStrings.localized(.trainingReminderSettingsView004))
          .font(.MeetPR.body(size: MeetPRFontMetrics.size14, weight: .semibold))
          .foregroundStyle(Color.MeetPR.textPrimary)
        weekdayPicker
        Rectangle()
          .fill(Color.MeetPR.borderSubtle)
          .frame(height: 1)
        DatePicker(
          StudentStrings.localized(.trainingReminderSettingsView005),
          selection: timeBinding,
          displayedComponents: .hourAndMinute
        )
        .font(.MeetPR.body(size: MeetPRFontMetrics.size14, weight: .semibold))
        .foregroundStyle(Color.MeetPR.textPrimary)
        .tint(Color.MeetPR.gold500)
      }
      .padding(MeetPRSpacing.space4)
      .background(Color.MeetPR.surfaceCard)
      .clipShape(.rect(cornerRadius: MeetPRRadius.card))
      .disabled(!viewModel.settings.isEnabled)
      .opacity(viewModel.settings.isEnabled ? 1 : 0.45)
    }
  }

  private var weekdayPicker: some View {
    LazyVGrid(
      columns: Array(
        repeating: GridItem(.flexible(), spacing: MeetPRSpacing.point6),
        count: TrainingReminderWeekday.allCases.count
      ),
      spacing: MeetPRSpacing.point6
    ) {
      ForEach(TrainingReminderWeekday.allCases) { weekday in
        let isSelected = viewModel.settings.weekdays.contains(weekday)
        Button {
          Task { await viewModel.toggle(weekday) }
        } label: {
          Text(weekday.shortName())
            .font(.MeetPR.body(size: MeetPRFontMetrics.size12, weight: .semibold))
            .foregroundStyle(
              isSelected ? Color.MeetPR.inkOnCTAFill : Color.MeetPR.textSecondary
            )
            .frame(maxWidth: .infinity, minHeight: MeetPRSpacing.minimumHitTarget)
            .background(isSelected ? Color.MeetPR.ctaFill : Color.MeetPR.surfaceRaised)
            .clipShape(.rect(cornerRadius: MeetPRRadius.control))
            .overlay {
              RoundedRectangle(cornerRadius: MeetPRRadius.control)
                .stroke(
                  isSelected ? Color.MeetPR.gold500 : Color.MeetPR.borderSubtle,
                  lineWidth: 1
                )
            }
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
      }
    }
  }

  private var permissionWarning: some View {
    HStack(alignment: .center, spacing: MeetPRSpacing.space3) {
      Image(systemName: "exclamationmark.triangle.fill")
        .foregroundStyle(Color.MeetPR.dangerMuted)
      Text(StudentStrings.localized(.trainingReminderSettingsView006))
        .font(.MeetPR.body(size: MeetPRFontMetrics.size13, weight: .semibold))
        .foregroundStyle(Color.MeetPR.textSecondary)
        .frame(maxWidth: .infinity, alignment: .leading)
      Button(StudentStrings.localized(.trainingReminderSettingsView007)) {
        openNotificationSettings()
      }
      .font(.MeetPR.body(size: MeetPRFontMetrics.size13, weight: .semibold))
      .foregroundStyle(Color.MeetPR.goldText)
    }
    .padding(MeetPRSpacing.space4)
    .background(Color.MeetPR.dangerRGB.opacity(0.08))
    .clipShape(.rect(cornerRadius: MeetPRRadius.card))
    .overlay {
      RoundedRectangle(cornerRadius: MeetPRRadius.card)
        .stroke(Color.MeetPR.dangerRGB.opacity(0.25), lineWidth: 1)
    }
  }

  private var scheduleFailureWarning: some View {
    HStack(alignment: .center, spacing: MeetPRSpacing.space3) {
      Image(systemName: "exclamationmark.triangle.fill")
        .foregroundStyle(Color.MeetPR.dangerMuted)
      Text(StudentStrings.localized(.trainingReminderSettingsView008))
        .font(.MeetPR.body(size: MeetPRFontMetrics.size13, weight: .semibold))
        .foregroundStyle(Color.MeetPR.textSecondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(MeetPRSpacing.space4)
    .background(Color.MeetPR.dangerRGB.opacity(0.08))
    .clipShape(.rect(cornerRadius: MeetPRRadius.card))
    .overlay {
      RoundedRectangle(cornerRadius: MeetPRRadius.card)
        .stroke(Color.MeetPR.dangerRGB.opacity(0.25), lineWidth: 1)
    }
  }

  private var enabledBinding: Binding<Bool> {
    Binding(
      get: { viewModel.settings.isEnabled },
      set: { isEnabled in
        Task { await viewModel.setEnabled(isEnabled) }
      }
    )
  }

  private var timeBinding: Binding<Date> {
    Binding(
      get: {
        Calendar.current.date(
          from: DateComponents(
            year: 2001,
            month: 1,
            day: 1,
            hour: viewModel.settings.hour,
            minute: viewModel.settings.minute
          )
        ) ?? Date(timeIntervalSinceReferenceDate: 0)
      },
      set: { date in
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        guard let hour = components.hour, let minute = components.minute else { return }
        Task { await viewModel.setTime(hour: hour, minute: minute) }
      }
    )
  }

  private func openNotificationSettings() {
    #if os(iOS)
      guard let url = URL(string: UIApplication.openNotificationSettingsURLString) else { return }
      openURL(url)
    #endif
  }
}
