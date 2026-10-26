import Analytics
import CoreModels
import DesignSystem
import SwiftUI

struct BindWelcomeView: View {
  let request: BindRequest
  let onContinue: () -> Void
  @State private var model: BindWelcomeViewModel
  @State private var hasTrackedView = false
  @Environment(\.scenePhase) private var scenePhase

  init(
    request: BindRequest, permission: StudentNotificationPermissionActions,
    onContinue: @escaping () -> Void
  ) {
    self.request = request
    self.onContinue = onContinue
    _model = State(initialValue: BindWelcomeViewModel(permission: permission))
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 32) {
        Text(String(BindWelcomePresentation.coachName(request.coachDisplayName).prefix(1)))
          .font(.largeTitle.bold())
          .foregroundStyle(Color.MeetPR.goldText)
          .frame(width: 72, height: 72)
          .background(Color.MeetPR.gold500.opacity(0.08), in: .circle)
          .overlay { Circle().stroke(Color.MeetPR.gold500, lineWidth: 1) }
          .accessibilityHidden(true)
        VStack(alignment: .leading, spacing: 10) {
          Text(StudentStrings.localized(.bindWelcomeSuccess))
            .font(.MeetPR.mono(size: MeetPRFontMetrics.size13))
            .foregroundStyle(Color.MeetPR.goldText)
          Text(BindWelcomePresentation.title(request.coachDisplayName))
            .font(.largeTitle.weight(.heavy))
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityIdentifier("bind.welcome.title")
        }
        VStack(spacing: 0) {
          BindWelcomeStep(number: 1, title: .bindWelcomeStep1, detail: .bindWelcomeDetail1)
          BindWelcomeStep(number: 2, title: .bindWelcomeStep2, detail: .bindWelcomeDetail2)
          BindWelcomeStep(number: 3, title: .bindWelcomeStep3, detail: .bindWelcomeDetail3)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.horizontal, 24)
      .padding(.top, 44)
      .padding(.bottom, 32)
    }
    .scrollIndicators(.hidden)
    .foregroundStyle(Color.MeetPR.textPrimary)
    .background(Color.MeetPR.bgBase)
    .safeAreaInset(edge: .bottom) {
      VStack(spacing: 12) {
        #if os(iOS)
          if model.canRequestPermission {
            Button {
              Task { await model.requestPermission() }
            } label: {
              Label(StudentStrings.localized(.bindWelcomeRemind), systemImage: "bell")
                .font(.callout.bold())
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(Color.MeetPR.surfaceCard, in: .capsule)
                .overlay { Capsule().stroke(Color.MeetPR.borderStrong, lineWidth: 1) }
                .contentShape(.capsule)
            }
            .disabled(model.isRequesting)
            .accessibilityIdentifier("bind.welcome.remind")
          }
        #endif
        Button {
          Analytics.shared.track(.bindWelcomeContinue)
          onContinue()
        } label: {
          Text(StudentStrings.localized(.bindWelcomeContinue))
            .font(.headline)
            .foregroundStyle(Color.MeetPR.surfaceCard)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(Color.MeetPR.textPrimary, in: .capsule)
            .contentShape(.capsule)
        }
        .accessibilityIdentifier("bind.welcome.continue")
      }
      .foregroundStyle(Color.MeetPR.textPrimary)
      .padding(.horizontal, 24)
      .padding(.bottom, 12)
      .background(Color.MeetPR.bgBase)
    }
    .task {
      if !hasTrackedView {
        Analytics.shared.track(.bindWelcomeViewed)
        hasTrackedView = true
      }
      await model.refreshPermission()
    }
    .onChange(of: scenePhase) { _, phase in
      if phase == .active { Task { await model.refreshPermission() } }
    }
  }
}

private struct BindWelcomeStep: View {
  let number: Int
  let title: StudentStrings.Key
  let detail: StudentStrings.Key

  var body: some View {
    HStack(alignment: .top, spacing: 14) {
      Text(number.formatted())
        .font(.callout.bold())
        .foregroundStyle(Color.MeetPR.surfaceCard)
        .frame(width: 28, height: 28)
        .background(Color.MeetPR.textPrimary, in: .circle)
      VStack(alignment: .leading, spacing: 6) {
        Text(StudentStrings.localized(title)).font(.callout.bold())
        Text(StudentStrings.localized(detail))
          .font(.subheadline)
          .foregroundStyle(Color.MeetPR.textSecondary)
      }
      .fixedSize(horizontal: false, vertical: true)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.vertical, 14)
  }
}

enum BindWelcomePresentation {
  static func coachName(_ displayName: String?, locale: Locale = .current) -> String {
    let name = displayName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    guard !name.isEmpty else { return StudentStrings.localized(.bindWelcomeCoach, locale: locale) }
    guard InterfaceLanguage(locale: locale) != .english else { return name }
    let coach = StudentStrings.localized(.bindWelcomeCoach, locale: locale)
    return name.contains("教练") || name.contains("教練") ? name : name + coach
  }

  static func title(_ displayName: String?, locale: Locale = .current) -> String {
    StudentStrings.replacing(
      .bindWelcomeTitle, values: [coachName(displayName, locale: locale)], locale: locale)
  }
}
