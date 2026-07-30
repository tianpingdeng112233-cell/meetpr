import CoreModels
import DesignSystem
import SwiftUI

@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct StudentProfileSection: View {
  let state: StudentProfileState
  let now: Date

  var body: some View {
    ScrollView {
      switch state {
      case .loading:
        ProgressView()
          .frame(maxWidth: .infinity)
          .padding(.top, MeetPRSpacing.point32)
      case .unavailable:
        Text(CoachDetailStrings.profileUnavailable)
          .font(.MeetPR.body(size: MeetPRFontMetrics.size15, weight: .semibold))
          .foregroundStyle(Color.MeetPR.textTertiary)
          .frame(maxWidth: .infinity)
          .padding(.top, MeetPRSpacing.point32)
      case .loaded(let profile):
        VStack(alignment: .leading, spacing: MeetPRSpacing.space3) {
          oneRMCard(profile)
          Text(CoachProfileStrings.registrationAnswers)
            .font(.MeetPR.mono(size: MeetPRFontMetrics.size12))
            .foregroundStyle(Color.MeetPR.textTertiary)
            .padding(.top, MeetPRSpacing.space3)
          questionnaireCard(profile)
        }
        .padding(.horizontal, MeetPRSpacing.pageHorizontal)
        .padding(.bottom, MeetPRSpacing.point28)
      }
    }
    .scrollIndicators(.hidden)
    .background(Color.MeetPR.bgBase)
  }

  private func oneRMCard(_ profile: OnboardingProfile) -> some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.point7) {
      HStack {
        Text(CoachProfileStrings.currentOneRM)
          .font(.MeetPR.body(size: MeetPRFontMetrics.size11, weight: .semibold))
          .foregroundStyle(Color.MeetPR.gold500)
        Spacer()
        Text(CoachProfileStrings.edit)
          .font(.MeetPR.body(size: MeetPRFontMetrics.size12, weight: .semibold))
          .foregroundStyle(Color.MeetPR.textPrimary)
          .padding(.horizontal, MeetPRSpacing.space3)
          .padding(.vertical, MeetPRSpacing.point5)
          .overlay {
            Capsule()
              .stroke(Color.MeetPR.borderStrong, lineWidth: MeetPRSpacing.point1)
          }
          .accessibilityAddTraits(.isButton)
          .accessibilityHint(CoachProfileStrings.editUnavailable)
      }
      Text(oneRMText(profile))
        .font(.MeetPR.mono(size: MeetPRFontMetrics.size17, weight: .bold))
        .foregroundStyle(Color.MeetPR.textPrimary)
      Text(CoachProfileStrings.oneRMExplanation)
        .font(.MeetPR.body(size: MeetPRFontMetrics.size12))
        .foregroundStyle(Color.MeetPR.textTertiary)
    }
    .padding(MeetPRSpacing.point15)
    .meetPRCardSurface(.card)
  }

  private func questionnaireCard(_ profile: OnboardingProfile) -> some View {
    VStack(spacing: 0) {
      profileRow(CoachProfileStrings.basicInfo, basicInfo(profile))
      profileRow(CoachProfileStrings.weightClass, profile.targetWeightClass)
      profileRow(CoachProfileStrings.trainingHistory, trainingHistory(profile))
      profileRow(CoachProfileStrings.trainingEnvironment, environment(profile))
      profileRow(CoachProfileStrings.targetMeet, targetMeet(profile))
      profileRow(
        CoachProfileStrings.focus,
        profile.muscleGroupsToStrengthen.isEmpty
          ? nil
          : CoachOnboardingDisplay.muscleGroupList(profile.muscleGroupsToStrengthen)
      )
      profileRow(CoachProfileStrings.injuryHistory, injury(profile))
      profileRow(CoachProfileStrings.diet, nil)
      profileRow(
        CoachProfileStrings.studentSaid,
        profile.noteToCoach.map { "「\($0)」" },
        bodySize: MeetPRFontMetrics.size14
      )
      profileRow(
        CoachProfileStrings.joinedAt,
        profile.createdAt.formatted(
          .dateTime.year().month(.twoDigits).day(.twoDigits)
            .locale(Locale(identifier: "zh_Hans_CN"))
        ),
        isMono: true
      )
    }
    .meetPRCardSurface(.card)
  }

  private func profileRow(
    _ label: String,
    _ value: String?,
    bodySize: CGFloat = MeetPRFontMetrics.size15,
    isMono: Bool = false
  ) -> some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.space1) {
      Text(label)
        .font(.MeetPR.body(size: MeetPRFontMetrics.size11))
        .foregroundStyle(Color.MeetPR.textTertiary)
      Text(value ?? CoachProfileStrings.notProvided)
        .font(
          isMono
            ? .MeetPR.mono(size: bodySize, weight: .semibold)
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
      values.append(CoachProfileStrings.age(age))
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
      values.append(CoachProfileStrings.weeklyFrequency(profile.trainingDays.count))
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
    return [profile.competitionDate, profile.targetWeightClass]
      .compactMap(\.self)
      .joined(separator: " · ")
      .nilIfEmpty
  }

  private func injury(_ profile: OnboardingProfile) -> String? {
    let areas = profile.injuryAreas
      .map(CoachOnboardingDisplay.injuryAreaText)
      .joined(separator: " · ")
    return [areas.nilIfEmpty, profile.injuryNotes]
      .compactMap(\.self)
      .joined(separator: " · ")
      .nilIfEmpty
  }
}

extension String {
  fileprivate var nilIfEmpty: String? {
    isEmpty ? nil : self
  }
}
