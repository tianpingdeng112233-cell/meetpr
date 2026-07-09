import CoreModels
import DesignSystem
import SwiftUI

/// 训练基线卡片 (spec 046 §4 / 050 §4): the three-lift baseline. Coached shows
/// the lock chrome + 联系教练; solo owns its baseline and gets a 补记/修改 entry.
@available(iOS 17.0, macOS 14.0, *)
struct OneRMBaselineCard: View {
  let profile: OnboardingProfile
  let trainingMode: TrainingMode
  let onEdit: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        Text("当前 1RM")
          .font(Font.MeetPR.monoLabel)
          .tracking(Font.MeetPR.monoLabelTracking)
          .foregroundStyle(Color.MeetPR.brandRed)
        Spacer()
        if trainingMode != .selfTrain {
          Image(systemName: "lock").font(.system(size: 14))
            .foregroundStyle(Color.MeetPR.fgTertiary)
        }
      }
      HStack(spacing: 12) {
        oneRMValue("深蹲", profile.squat1RMKg)
        oneRMValue("卧推", profile.bench1RMKg)
        oneRMValue("硬拉", profile.deadlift1RMKg)
      }
      .padding(.top, 12)
      if trainingMode == .selfTrain {
        // 后补入口 (spec 046 §2): solo's baseline belongs to the student.
        Button(action: onEdit) {
          HStack(spacing: 6) {
            Image(systemName: "square.and.pencil").font(.system(size: 12))
            Text(hasBaseline ? "修改入门基线" : "补记入门基线")
              .font(Font.MeetPR.monoLabel)
              .tracking(Font.MeetPR.monoLabelTracking)
          }
          .foregroundStyle(Color.MeetPR.brandRed)
        }
        .buttonStyle(.plain)
        .padding(.top, 14)
        .accessibilityIdentifier("profile.baseline.edit")
      } else {
        HStack(spacing: 6) {
          Image(systemName: "lock").font(.system(size: 12))
            .foregroundStyle(Color.MeetPR.fgTertiary)
          Text("训练周期中无法修改 · 联系教练")
            .font(Font.MeetPR.monoLabel)
            .tracking(Font.MeetPR.monoLabelTracking)
            .foregroundStyle(Color.MeetPR.fgTertiary)
        }
        .padding(.top, 14)
      }
    }
    .padding(18)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.MeetPR.surface1)
    .clipShape(.rect(cornerRadius: 12))
    .overlay { RoundedRectangle(cornerRadius: 12).stroke(Color.MeetPR.border, lineWidth: 1) }
  }

  private var hasBaseline: Bool {
    profile.squat1RMKg != nil || profile.bench1RMKg != nil || profile.deadlift1RMKg != nil
  }

  private func oneRMValue(_ label: String, _ value: Decimal?) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(label).font(.system(size: 12)).foregroundStyle(Color.MeetPR.fgTertiary)
      HStack(alignment: .lastTextBaseline, spacing: 3) {
        Text(value.map { UnitDisplay.plainString($0) } ?? "—")
          .font(.system(size: 30, weight: .heavy).monospacedDigit())
          .foregroundStyle(Color.MeetPR.fgPrimary)
        Text("kg").font(.system(size: 12, design: .monospaced))
          .foregroundStyle(Color.MeetPR.fgTertiary)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
}

/// 补记/修改入门基线 (spec 046 §2 后补入口): solo's baseline belongs to the
/// student (backend spec 013), so the coached lock chrome never appears and
/// the three fields stay editable after onboarding completes.
@available(iOS 17.0, macOS 14.0, *)
struct SoloBaselineEditSheet: View {
  /// MyProfileViewModel.save — false keeps the sheet up for a retry.
  private let save: (OnboardingPatch) async -> Bool
  @Environment(\.dismiss) private var dismiss
  @State private var draft: OnboardingDraft
  @State private var saving = false
  @State private var failed = false

  init(profile: OnboardingProfile, save: @escaping (OnboardingPatch) async -> Bool) {
    self.save = save
    // Seed in init, not onAppear — Step3's own onAppear snapshots the draft
    // into its text fields before a parent onAppear would run.
    var seeded = OnboardingDraft()
    seeded.squat1RMKg = profile.squat1RMKg
    seeded.bench1RMKg = profile.bench1RMKg
    seeded.deadlift1RMKg = profile.deadlift1RMKg
    self._draft = State(initialValue: seeded)
  }

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(alignment: .leading, spacing: MeetPRSpacing.lg) {
          Step3StrengthSection(draft: $draft, lockWarning: nil)

          Text("留空表示清除该项。基线只是入门锚点,实测走势见「成长」。")
            .font(Font.MeetPR.caption)
            .foregroundStyle(Color.MeetPR.fgTertiary)

          if failed {
            Label("保存失败,请重试", systemImage: "exclamationmark.triangle")
              .font(Font.MeetPR.caption)
              .foregroundStyle(Color.MeetPR.brandRed)
          }

          PrimaryButton(saving ? "保存中…" : "保存", isFullWidth: true) {
            Task { await submit() }
          }
          .accessibilityIdentifier("profile.baseline.save")
        }
        .padding(MeetPRSpacing.base)
      }
      .background(Color.MeetPR.bg)
      .navigationTitle("入门基线")
      #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
      #endif
    }
  }

  private func submit() async {
    guard !saving else { return }
    saving = true
    failed = false
    var patch = OnboardingPatch()
    patch.squat1RMKg = draft.squat1RMKg.map(Patch.value) ?? .null
    patch.bench1RMKg = draft.bench1RMKg.map(Patch.value) ?? .null
    patch.deadlift1RMKg = draft.deadlift1RMKg.map(Patch.value) ?? .null
    if await save(patch) {
      dismiss()
    } else {
      failed = true
      saving = false
    }
  }
}
