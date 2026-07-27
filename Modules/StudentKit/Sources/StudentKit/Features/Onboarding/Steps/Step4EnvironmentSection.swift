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
        equipmentSection
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
    case .homeWithRack: "家里有深蹲架和杠铃,自己安排训练"
    case .commercial: "连锁 / 综合健身房 — 有架有杠,力量举专项器械通常没有"
    case .professional: "力量举专项馆 — 专项杆、微增片、专项机齐全,可做全部变式"
    }
  }

  // MARK: - Equipment checklist (grouped, spec 032 D3 v2 vocabulary)

  private var equipmentSection: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.lg) {
      VStack(alignment: .leading, spacing: MeetPRSpacing.xs) {
        OnboardingFieldLabel(title: "器械微调")
        Text("按场馆预填 — 勾掉没有的、补上有的,不确定就保持默认")
          .font(.MeetPR.body(size: MeetPRFontMetrics.size11, weight: .medium))
          .foregroundStyle(Color.MeetPR.textMuted)
      }
      equipmentChipGrid("基础", .basics)
      OnboardingChoiceCards(
        title: "哑铃最大重量",
        options: EquipmentCatalog.items(in: .dumbbellMax).map {
          ($0.token, $0.label.replacingOccurrences(of: "哑铃 ", with: ""))
        },
        selection: dumbbellMaxSelection
      )
      equipmentChipGrid("固定器械", .machines)
      equipmentChipGrid("力量举专项", .powerlifting)
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
