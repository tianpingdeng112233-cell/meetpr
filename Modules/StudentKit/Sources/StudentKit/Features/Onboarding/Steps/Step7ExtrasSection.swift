import CoreModels
import DesignSystem
import SwiftUI

/// Step 7 补充信息: injuries, competition plan (conditional date), target
/// weight class, note to coach. Split into two sub-sections so the 伤病记录
/// and 比赛/备注 archive cards can edit their own halves (spec 032 §7).
@available(iOS 17.0, macOS 14.0, *)
struct Step7ExtrasSection: View {
  @Binding var draft: OnboardingDraft
  var highlighted: Set<String> = []

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.lg) {
      InjuryFieldsSection(draft: $draft)
      CompetitionFieldsSection(draft: $draft, highlighted: highlighted)
    }
  }
}

/// 伤病记录 fields (Step 7 upper half + card 8 edit).
@available(iOS 17.0, macOS 14.0, *)
struct InjuryFieldsSection: View {
  @Binding var draft: OnboardingDraft

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.lg) {
      OnboardingTextEditor(
        title: StudentStrings.localized(.step7ExtrasSection001),
        text: $draft.injuryNotes,
        placeholder: StudentStrings.localized(.step7ExtrasSection002)
      )
      OnboardingChipGrid(
        title: StudentStrings.localized(.step7ExtrasSection003),
        options: InjuryArea.allCases.map { ($0, OnboardingLabels.label($0)) },
        selection: $draft.injuryAreas,
        maxSelection: 8
      )
    }
  }
}

/// 比赛/备注 fields (Step 7 lower half + card 7 edit).
@available(iOS 17.0, macOS 14.0, *)
struct CompetitionFieldsSection: View {
  @Binding var draft: OnboardingDraft
  var highlighted: Set<String> = []

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.lg) {
      OnboardingChoiceCards(
        title: StudentStrings.localized(.step7ExtrasSection004),
        options: [
          (false, StudentStrings.localized(.step7ExtrasSection005)),
          (true, StudentStrings.localized(.step7ExtrasSection006)),
        ],
        selection: $draft.isCompeting,
        isHighlighted: highlighted.contains("is_competing")
      )
      if draft.isCompeting == true {
        competitionDatePicker
        MeetPRTextField(
          StudentStrings.localized(.step7ExtrasSection007),
          text: $draft.targetWeightClass,
          placeholder: StudentStrings.localized(.step7ExtrasSection008)
        )
      }
      OnboardingTextEditor(
        title: StudentStrings.localized(.step7ExtrasSection009),
        text: $draft.noteToCoach,
        placeholder: StudentStrings.localized(.step7ExtrasSection010)
      )
    }
  }

  private var competitionDatePicker: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
      OnboardingFieldLabel(
        title: StudentStrings.localized(.step7ExtrasSection011),
        isHighlighted: highlighted.contains("competition_date"))
      DatePicker(
        StudentStrings.localized(.step7ExtrasSection011),
        selection: DateOnly.binding($draft.competitionDate, default: Date()),
        in: Date()...,
        displayedComponents: .date
      )
      .labelsHidden()
      .onAppear {
        if draft.competitionDate == nil {
          draft.competitionDate = DateOnly.string(from: Date())
        }
      }
    }
  }
}
