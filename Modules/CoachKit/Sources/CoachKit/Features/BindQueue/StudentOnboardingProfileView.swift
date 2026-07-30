import CoreModels
import DesignSystem
import RepositoryContracts
import SwiftUI

@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct StudentOnboardingProfileView: View {
  enum LoadState: Equatable {
    case loading
    case loaded(OnboardingProfile)
    case unavailable
  }

  let item: CoachBindRequestItem
  let profiles: any OnboardingProfileReading
  let onAccept: () -> Void
  let onReject: () -> Void

  @Environment(\.coachNow) private var now
  @Environment(\.dismiss) private var dismiss
  @State private var state: LoadState = .loading

  var body: some View {
    VStack(spacing: 0) {
      header
      Group {
        switch state {
        case .loading:
          ProgressView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .unavailable:
          unavailableState
        case .loaded(let profile):
          profileContent(profile)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .background(Color.MeetPR.bgBase)
    .hideNavigationBar()
    .coachFullScreenDestination()
    .task {
      await load()
    }
  }

  private var header: some View {
    HStack(spacing: MeetPRSpacing.space3) {
      Button {
        dismiss()
      } label: {
        Image(systemName: "chevron.left")
          .font(.MeetPR.system(size: MeetPRFontMetrics.size20, weight: .semibold))
          .foregroundStyle(Color.MeetPR.textPrimary)
          .frame(width: MeetPRSpacing.point40, height: MeetPRSpacing.point40)
          .meetPRCardSurface(.card)
          .clipShape(.circle)
      }
      .buttonStyle(PressScaleButtonStyle(scale: 0.94))
      .accessibilityLabel(CoachApplicationProfileStrings.back)
      .accessibilityIdentifier("coach.applicationProfile.back")

      VStack(alignment: .leading, spacing: MeetPRSpacing.point2) {
        Text(CoachApplicationProfileStrings.title(item.displayName))
          .font(.MeetPR.body(size: MeetPRFontMetrics.size16, weight: .bold))
          .foregroundStyle(Color.MeetPR.textPrimary)
          .lineLimit(1)
        Text(CoachOnboardingDisplay.waitingText(since: item.submittedAt, now: now))
          .font(.MeetPR.body(size: MeetPRFontMetrics.size11))
          .foregroundStyle(Color.MeetPR.textTertiary)
      }
      .frame(maxWidth: .infinity, alignment: .leading)
    }
    .padding(.horizontal, MeetPRSpacing.point18)
    .padding(.top, MeetPRSpacing.space1)
    .padding(.bottom, MeetPRSpacing.point14)
    .overlay(alignment: .bottom) {
      Rectangle()
        .fill(Color.MeetPR.borderDefault)
        .frame(height: MeetPRSpacing.point1)
    }
  }

  private func profileContent(_ profile: OnboardingProfile) -> some View {
    ScrollView {
      VStack(spacing: MeetPRSpacing.space3) {
        profileCard(profile)
        actionRow
      }
      .padding(.horizontal, MeetPRSpacing.point18)
      .padding(.top, MeetPRSpacing.space4)
      .padding(.bottom, MeetPRSpacing.point26)
    }
    .scrollIndicators(.hidden)
  }

  private func profileCard(_ profile: OnboardingProfile) -> some View {
    VStack(spacing: 0) {
      row(CoachApplicationProfileStrings.basicInfo, basicInfo(profile))
      row(
        CoachApplicationProfileStrings.selfReportedOneRM,
        oneRMText(profile),
        isMono: true
      )
      row(CoachApplicationProfileStrings.trainingHistory, trainingHistory(profile))
      row(CoachApplicationProfileStrings.trainingEnvironment, environment(profile))
      row(CoachApplicationProfileStrings.targetMeet, targetMeet(profile))
      row(
        CoachApplicationProfileStrings.focus,
        profile.muscleGroupsToStrengthen.isEmpty
          ? nil
          : CoachOnboardingDisplay.muscleGroupList(profile.muscleGroupsToStrengthen)
      )
      row(CoachApplicationProfileStrings.injuryHistory, injury(profile))
      row(
        CoachApplicationProfileStrings.studentSaid(profile.gender),
        profile.noteToCoach.map { "「\($0)」" },
        bodySize: MeetPRFontMetrics.size14
      )
    }
    .meetPRCardSurface(.card)
  }

  private func row(
    _ label: String,
    _ value: String?,
    bodySize: CGFloat = MeetPRFontMetrics.size15,
    isMono: Bool = false
  ) -> some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.space1) {
      Text(label)
        .font(.MeetPR.body(size: MeetPRFontMetrics.size11))
        .foregroundStyle(Color.MeetPR.textTertiary)
      Text(value ?? CoachApplicationProfileStrings.notProvided)
        .font(
          isMono
            ? .MeetPR.mono(size: bodySize, weight: .bold)
            : .MeetPR.body(size: bodySize, weight: .semibold)
        )
        .foregroundStyle(Color.MeetPR.textPrimary)
        .lineSpacing(MeetPRSpacing.point7)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, MeetPRSpacing.space4)
    .padding(.vertical, MeetPRSpacing.point13)
    .overlay(alignment: .top) {
      Rectangle()
        .fill(Color.MeetPR.borderHairline)
        .frame(height: MeetPRSpacing.point1)
    }
  }

  private var actionRow: some View {
    HStack(spacing: MeetPRSpacing.point9) {
      Button(CoachApplicationProfileStrings.accept, action: onAccept)
        .font(.MeetPR.body(size: MeetPRFontMetrics.size14, weight: .bold))
        .foregroundStyle(Color.MeetPR.inkOnCTAFill)
        .frame(maxWidth: .infinity)
        .padding(.vertical, MeetPRSpacing.point14)
        .background(Color.MeetPR.textPrimary)
        .clipShape(.capsule)
        .buttonStyle(PressScaleButtonStyle(scale: 0.97))
        .accessibilityIdentifier("coach.applicationProfile.accept")

      Button(CoachApplicationProfileStrings.ignore, action: onReject)
        .font(.MeetPR.body(size: MeetPRFontMetrics.size14, weight: .semibold))
        .foregroundStyle(Color.MeetPR.textTertiary)
        .padding(.horizontal, MeetPRSpacing.space5)
        .padding(.vertical, MeetPRSpacing.point14)
        .overlay {
          Capsule()
            .stroke(Color.MeetPR.borderDefault, lineWidth: MeetPRSpacing.point1)
        }
        .buttonStyle(PressScaleButtonStyle(scale: 0.97))
        .accessibilityIdentifier("coach.applicationProfile.ignore")
    }
  }

  private var unavailableState: some View {
    VStack(spacing: MeetPRSpacing.point10) {
      Text(CoachApplicationProfileStrings.unavailable)
        .font(.MeetPR.body(size: MeetPRFontMetrics.size15, weight: .semibold))
        .foregroundStyle(Color.MeetPR.textPrimary)
      Text(CoachApplicationProfileStrings.unavailableSubtitle)
        .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
        .foregroundStyle(Color.MeetPR.textDisabled)
        .multilineTextAlignment(.center)
      actionRow
        .padding(.top, MeetPRSpacing.space3)
    }
    .padding(.horizontal, MeetPRSpacing.point18)
  }

  private func oneRMText(_ profile: OnboardingProfile) -> String {
    let squat = profile.squat1RMKg.map(CoachOnboardingDisplay.decimalText) ?? "—"
    let bench = profile.bench1RMKg.map(CoachOnboardingDisplay.decimalText) ?? "—"
    let deadlift = profile.deadlift1RMKg.map(CoachOnboardingDisplay.decimalText) ?? "—"
    return "S:\(squat)　B:\(bench)　D:\(deadlift) (kg)"
  }

  private func basicInfo(_ profile: OnboardingProfile) -> String? {
    var values: [String] = []
    if let gender = profile.gender {
      values.append(CoachOnboardingDisplay.genderText(gender))
    }
    if let age = CoachOnboardingDisplay.age(
      birthDate: profile.birthDate,
      now: now,
      calendar: CoachFeatureCalendar.calendar
    ) {
      values.append(CoachApplicationProfileStrings.age(age))
    }
    if let height = profile.heightCm {
      values.append("\(CoachOnboardingDisplay.decimalText(height)) cm")
    }
    if let weight = profile.weightKg {
      values.append("\(CoachOnboardingDisplay.decimalText(weight)) kg")
    }
    return values.isEmpty ? nil : values.joined(separator: " · ")
  }

  private func trainingHistory(_ profile: OnboardingProfile) -> String? {
    var values: [String] = []
    if let years = profile.trainingYears {
      values.append(CoachOnboardingDisplay.trainingYearsText(years))
    }
    if !profile.trainingDays.isEmpty {
      values.append(CoachApplicationProfileStrings.weeklyFrequency(profile.trainingDays.count))
    }
    return values.isEmpty ? nil : values.joined(separator: " · ")
  }

  private func environment(_ profile: OnboardingProfile) -> String? {
    var values: [String] = []
    if let gymTier = profile.gymTier {
      values.append(CoachOnboardingDisplay.gymTierText(gymTier))
    }
    if !profile.equipmentOverrides.isEmpty {
      values.append(
        profile.equipmentOverrides
          .map(CoachOnboardingDisplay.equipmentLabel)
          .joined(separator: " · ")
      )
    }
    return values.isEmpty ? nil : values.joined(separator: " · ")
  }

  private func targetMeet(_ profile: OnboardingProfile) -> String? {
    guard profile.isCompeting == true else { return nil }
    let text = [profile.competitionDate, profile.targetWeightClass]
      .compactMap(\.self)
      .joined(separator: " · ")
    return text.isEmpty ? nil : text
  }

  private func injury(_ profile: OnboardingProfile) -> String? {
    let areas = profile.injuryAreas
      .map(CoachOnboardingDisplay.injuryAreaText)
      .joined(separator: " · ")
    let text = [areas.isEmpty ? nil : areas, profile.injuryNotes]
      .compactMap(\.self)
      .joined(separator: " · ")
    return text.isEmpty ? nil : text
  }

  private func load() async {
    if let profile = try? await profiles.fetchProfile(studentId: item.studentId) {
      state = .loaded(profile)
    } else {
      state = .unavailable
    }
  }
}

enum CoachApplicationProfileStrings {
  static let back = CoachLocalization.localized("coach.applicationProfile.back")
  static let basicInfo = CoachLocalization.localized("coach.applicationProfile.basicInfo")
  static let selfReportedOneRM = CoachLocalization.localized(
    "coach.applicationProfile.selfReportedOneRM")
  static let trainingHistory = CoachLocalization.localized(
    "coach.applicationProfile.trainingHistory")
  static let trainingEnvironment = CoachLocalization.localized(
    "coach.applicationProfile.trainingEnvironment")
  static let targetMeet = CoachLocalization.localized("coach.applicationProfile.targetMeet")
  static let focus = CoachLocalization.localized("coach.applicationProfile.focus")
  static let injuryHistory = CoachLocalization.localized(
    "coach.applicationProfile.injuryHistory")
  static let accept = CoachLocalization.localized("coach.applicationProfile.accept")
  static let ignore = CoachLocalization.localized("coach.applicationProfile.ignore")
  static let notProvided = CoachLocalization.localized("coach.applicationProfile.notProvided")
  static let unavailable = CoachLocalization.localized("coach.applicationProfile.unavailable")
  static let unavailableSubtitle = CoachLocalization.localized(
    "coach.applicationProfile.unavailableSubtitle")

  static func title(_ name: String) -> String {
    CoachLocalization.replacing(
      "coach.applicationProfile.title",
      values: ["name": name]
    )
  }

  static func age(_ age: Int) -> String {
    CoachLocalization.replacing(
      "coach.applicationProfile.age",
      values: ["age": age.formatted()]
    )
  }

  static func weeklyFrequency(_ count: Int) -> String {
    CoachLocalization.replacing(
      "coach.applicationProfile.weeklyFrequency",
      values: ["count": count.formatted()]
    )
  }

  static func studentSaid(_ gender: Gender?) -> String {
    switch gender {
    case .male: CoachLocalization.localized("coach.applicationProfile.heSaid")
    case .female: CoachLocalization.localized("coach.applicationProfile.sheSaid")
    case .other, nil: CoachLocalization.localized("coach.applicationProfile.theySaid")
    }
  }
}
