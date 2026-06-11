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
        title: "每周哪几天能练?",
        options: TrainingDay.allCases.map { ($0, OnboardingLabels.label($0)) },
        selection: $draft.trainingDays,
        maxSelection: 6,
        isHighlighted: highlighted.contains("training_days"),
        footer: daysFooter
      )
      tierPicker
      if draft.gymTier != nil {
        OnboardingChipGrid(
          title: "器械微调(按场馆预填,可调整)",
          options: EquipmentCatalog.items.map { ($0.token, $0.label) },
          selection: $draft.equipmentOverrides
        )
      }
    }
    .confirmationDialog(
      "切换场馆类型?",
      isPresented: Binding(
        get: { pendingTier != nil },
        set: { if !$0 { pendingTier = nil } }
      ),
      titleVisibility: .visible
    ) {
      Button("切换并重置器械清单") {
        if let tier = pendingTier {
          applyTier(tier)
        }
        pendingTier = nil
      }
      Button("取消", role: .cancel) { pendingTier = nil }
    } message: {
      Text("器械清单将重置为该场馆的预设,手动调整会丢失。")
    }
  }

  private var daysFooter: String {
    let count = draft.trainingDays.count
    if count < 2 {
      return "已选 \(count) 天/周 — 至少选 2 天"
    }
    return "已选 \(count) 天/周"
  }

  private var tierPicker: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.sm) {
      OnboardingFieldLabel(
        title: "训练场馆", isHighlighted: highlighted.contains("gym_tier"))
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
        Text(OnboardingLabels.label(tier))
          .font(Font.MeetPR.body)
          .foregroundStyle(isSelected ? Color.MeetPR.fgPrimary : Color.MeetPR.fgSecondary)
        Spacer()
        if isSelected {
          Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(Color.MeetPR.brandRed)
        }
      }
      .padding(MeetPRSpacing.md)
      .background(isSelected ? Color.MeetPR.brandRedSoft : Color.MeetPR.surface1)
      .overlay {
        RoundedRectangle(cornerRadius: MeetPRRadius.md)
          .stroke(isSelected ? Color.MeetPR.brandRed : Color.MeetPR.border, lineWidth: 1)
      }
      .clipShape(.rect(cornerRadius: MeetPRRadius.md))
    }
    .buttonStyle(.plain)
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
