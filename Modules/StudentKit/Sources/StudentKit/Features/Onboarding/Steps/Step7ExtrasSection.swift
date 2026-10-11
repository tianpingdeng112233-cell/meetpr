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

/// Optional meet section shared by the onboarding wizard.
struct CompetitionFieldsSection: View {
  @Binding var draft: OnboardingDraft
  var highlighted: Set<String> = []

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.lg) {
      HStack {
        OnboardingFieldLabel(title: StudentStrings.localized(.meetTitle))
        Spacer()
        if draft.isCompeting == true {
          Button(StudentStrings.localized(.meetRemoveAction)) {
            draft.isCompeting = false
            draft.competitionDate = nil
            draft.targetWeightClass = ""
          }
        }
      }
      if draft.isCompeting == true {
        MeetFieldsSection(draft: $draft, showsErrors: !highlighted.isEmpty)
      } else {
        Button {
          draft.isCompeting = true
          draft.competitionDate = DateOnly.string(from: Date())
        } label: {
          Label(StudentStrings.localized(.meetAddOptional), systemImage: "plus")
            .frame(maxWidth: .infinity, minHeight: MeetPRSpacing.minimumHitTarget)
            .foregroundStyle(Color.MeetPR.goldText)
            .overlay {
              RoundedRectangle(cornerRadius: MeetPRRadius.control)
                .stroke(Color.MeetPR.borderStrong, style: StrokeStyle(lineWidth: 1, dash: [4]))
            }
        }
        Text(StudentStrings.localized(.meetHelp))
          .font(.MeetPR.body(size: MeetPRFontMetrics.size13))
          .foregroundStyle(Color.MeetPR.textMuted)
      }
      NoteToCoachFieldsSection(note: $draft.noteToCoach)
    }
  }
}

struct NoteToCoachFieldsSection: View {
  @Binding var note: String

  var body: some View {
    OnboardingTextEditor(
      title: StudentStrings.localized(.step7ExtrasSection009),
      text: $note,
      placeholder: StudentStrings.localized(.step7ExtrasSection010)
    )
  }
}
