import CoreModels
import DesignSystem
import SwiftUI

/// Step 4 训练环境: training days (2-6), gym tier (selection resets the
/// equipment prefill after a confirm — D3), equipment checklist.
@available(iOS 17.0, macOS 14.0, *)
struct Step4EnvironmentSection: View {
  @Binding var draft: OnboardingDraft
  var highlighted: Set<String> = []
  @State private var pendingTier: GymTier?

  var body: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.lg) {
      OnboardingChipGrid(
        title: StudentStrings.localized(.step4EnvironmentSection001),
        options: TrainingDay.allCases.map { ($0, OnboardingLabels.label($0)) },
        selection: $draft.trainingDays,
        maxSelection: 6,
        isHighlighted: highlighted.contains("training_days"),
        footer: daysFooter
      )
      tierPicker
      if draft.gymTier != nil {
        equipmentSection
      }
    }
    .confirmationDialog(
      StudentStrings.localized(.step4EnvironmentSection002),
      isPresented: Binding(
        get: { pendingTier != nil },
        set: { if !$0 { pendingTier = nil } }
      ),
      titleVisibility: .visible
    ) {
      Button(StudentStrings.localized(.step4EnvironmentSection003)) {
        if let tier = pendingTier {
          applyTier(tier)
        }
        pendingTier = nil
      }
      Button(StudentStrings.localized(.step4EnvironmentSection004), role: .cancel) {
        pendingTier = nil
      }
    } message: {
      Text(StudentStrings.localized(.step4EnvironmentSection005))
    }
  }

  private var daysFooter: String {
    let count = draft.trainingDays.count
    if count < 2 {
      return StudentStrings.replacing(.step4EnvironmentSection006, values: ["\(count)"])
    }
    return StudentStrings.replacing(.step4EnvironmentSection007, values: ["\(count)"])
  }

  private var tierPicker: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
      OnboardingFieldLabel(
        title: StudentStrings.localized(.step4EnvironmentSection008),
        isHighlighted: highlighted.contains("gym_tier"))
      VStack(spacing: MeetPRSpacing.sm) {
        ForEach(GymTier.allCases, id: \.self) { tier in
          tierCard(tier)
        }
      }
    }
  }

  private func tierCard(_ tier: GymTier) -> some View {
    let isSelected = draft.gymTier == tier
    return Button {
      selectTier(tier)
    } label: {
      HStack {
        VStack(alignment: .leading, spacing: MeetPRSpacing.xs) {
          Text(OnboardingLabels.label(tier))
            .font(.MeetPR.body(size: MeetPRFontMetrics.size17))
            .foregroundStyle(isSelected ? Color.MeetPR.goldText : Color.MeetPR.textMuted)
          Text(Self.tierSubtitle(tier))
            .font(.MeetPR.body(size: MeetPRFontMetrics.size11, weight: .medium))
            .foregroundStyle(Color.MeetPR.textMuted)
            .multilineTextAlignment(.leading)
        }
        Spacer()
        if isSelected {
          Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(Color.MeetPR.gold500)
        }
      }
      .padding(MeetPRSpacing.md)
      .background(
        isSelected ? Color.MeetPR.goldRGB.opacity(0.12) : Color.MeetPR.surfaceCard
      )
      .overlay {
        RoundedRectangle(cornerRadius: MeetPRRadius.md)
          .stroke(
            isSelected ? Color.MeetPR.goldRGB.opacity(0.4) : Color.MeetPR.borderDefault,
            lineWidth: 1
          )
      }
      .clipShape(.rect(cornerRadius: MeetPRRadius.md))
    }
    .buttonStyle(.plain)
  }

  /// One-line "你能做什么" summary per tier (research: 让学员一眼自判;
  /// wiki domain/gym-tier-equipment-research.md §4b).
  private static func tierSubtitle(_ tier: GymTier) -> String {
    switch tier {
    case .homeWithRack: StudentStrings.localized(.step4EnvironmentSection009)
    case .commercial: StudentStrings.localized(.step4EnvironmentSection010)
    case .professional: StudentStrings.localized(.step4EnvironmentSection011)
    }
  }

  // MARK: - Equipment checklist (grouped, spec 032 D3 v2 vocabulary)

  private var equipmentSection: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.lg) {
      VStack(alignment: .leading, spacing: MeetPRSpacing.xs) {
        OnboardingFieldLabel(title: StudentStrings.localized(.step4EnvironmentSection012))
        Text(StudentStrings.localized(.step4EnvironmentSection013))
          .font(.MeetPR.body(size: MeetPRFontMetrics.size11, weight: .medium))
          .foregroundStyle(Color.MeetPR.textMuted)
      }
      equipmentChipGrid(StudentStrings.localized(.step4EnvironmentSection014), .basics)
      OnboardingChoiceCards(
        title: StudentStrings.localized(.step4EnvironmentSection015),
        options: EquipmentCatalog.items(in: .dumbbellMax).map {
          (
            $0.token,
            $0.label.replacingOccurrences(
              of: StudentStrings.localized(.step4EnvironmentSection016), with: "")
          )
        },
        selection: dumbbellMaxSelection
      )
      equipmentChipGrid(StudentStrings.localized(.step4EnvironmentSection017), .machines)
      equipmentChipGrid(StudentStrings.localized(.step4EnvironmentSection018), .powerlifting)
    }
  }

  private func equipmentChipGrid(_ title: String, _ group: EquipmentItem.Group) -> some View {
    OnboardingChipGrid(
      title: title,
      options: EquipmentCatalog.items(in: group).map { ($0.token, $0.label) },
      selection: $draft.equipmentOverrides
    )
  }

  /// The dumbbell cap is a bucket, not independent switches: picking one
  /// replaces whichever bucket token is currently in the overrides.
  private var dumbbellMaxSelection: Binding<String?> {
    Binding(
      get: {
        draft.equipmentOverrides.first { EquipmentCatalog.dumbbellMaxTokens.contains($0) }
      },
      set: { newValue in
        draft.equipmentOverrides.removeAll { EquipmentCatalog.dumbbellMaxTokens.contains($0) }
        if let newValue {
          draft.equipmentOverrides.append(newValue)
        }
      }
    )
  }

  private func selectTier(_ tier: GymTier) {
    guard tier != draft.gymTier else { return }
    if draft.gymTier == nil {
      // First selection: prefill without ceremony.
      applyTier(tier)
    } else {
      // Tier switch discards manual tweaks → confirm first (D3).
      pendingTier = tier
    }
  }

  private func applyTier(_ tier: GymTier) {
    draft.gymTier = tier
    draft.equipmentOverrides = EquipmentCatalog.prefill(for: tier)
  }
}
