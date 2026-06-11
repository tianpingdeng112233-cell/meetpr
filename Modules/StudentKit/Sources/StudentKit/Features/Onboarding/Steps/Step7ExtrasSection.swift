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
        title: "伤病记录(可选)",
        text: $draft.injuryNotes,
        placeholder: "如:左肩撞击综合征,深蹲低杠位时疼"
      )
      OnboardingChipGrid(
        title: "伤病部位(可选)",
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
        title: "是否在备赛?",
        options: [(false, "没有"), (true, "有比赛计划")],
        selection: $draft.isCompeting,
        isHighlighted: highlighted.contains("is_competing")
      )
      if draft.isCompeting == true {
        competitionDatePicker
        MeetPRTextField(
          "目标体重级别(可选)",
          text: $draft.targetWeightClass,
          placeholder: "例:IPF 83kg / WP -82.5kg"
        )
      }
      OnboardingTextEditor(
        title: "想对教练说什么?(可选)",
        text: $draft.noteToCoach,
        placeholder: "目标、习惯、顾虑都可以写"
      )
    }
  }

  private var competitionDatePicker: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
      OnboardingFieldLabel(
        title: "比赛日期", isHighlighted: highlighted.contains("competition_date"))
      DatePicker(
        "比赛日期",
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
