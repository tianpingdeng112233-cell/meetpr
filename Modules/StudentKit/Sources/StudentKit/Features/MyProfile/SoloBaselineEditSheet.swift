import CoreModels
import DesignSystem
import SwiftUI

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
