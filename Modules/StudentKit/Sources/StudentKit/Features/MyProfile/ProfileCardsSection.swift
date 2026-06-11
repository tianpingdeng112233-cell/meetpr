import CoreModels
import DesignSystem
import RepositoryContracts
import SwiftUI

/// The nine archive cards (spec 032 §7): scan state = icon + title +
/// summary line; tap pushes the card's edit page. Card 3 (1RM) is read-only
/// with the lock note; card 9 (教练评估) goes live once a summary exists
/// (spec 033 §12).
@available(iOS 17.0, macOS 14.0, *)
struct ProfileCardsSection: View {
  let profile: OnboardingProfile
  let viewModel: MyProfileViewModel
  var evaluationSummaryViewModel: StudentEvaluationSummaryViewModel?

  var body: some View {
    Section("我的资料") {
      editableRow(.basics, icon: "person.text.rectangle", title: "基础信息") {
        OnboardingSummaryFormatter.basics(profile)
      }
      editableRow(.background, icon: "figure.strengthtraining.traditional", title: "训练背景") {
        OnboardingSummaryFormatter.background(profile)
      }
      oneRMRow
      editableRow(.environment, icon: "calendar", title: "训练环境") {
        OnboardingSummaryFormatter.environment(profile)
      }
      editableRow(.recovery, icon: "bed.double", title: "恢复能力") {
        OnboardingSummaryFormatter.recovery(profile)
      }
      editableRow(.materials, icon: "folder", title: "训练资料") {
        OnboardingSummaryFormatter.materials(profile)
      }
      editableRow(.competition, icon: "target", title: "比赛/备注") {
        OnboardingSummaryFormatter.competition(profile)
      }
      editableRow(.injuries, icon: "bandage", title: "伤病记录") {
        OnboardingSummaryFormatter.injuries(profile)
      }
      evaluationRow
    }
    .listRowBackground(Color.MeetPR.surface1)
  }

  /// Card 9: live entry to the coach's evaluation summary once written;
  /// the pre-033 placeholder otherwise.
  @ViewBuilder
  private var evaluationRow: some View {
    if let evaluationSummaryViewModel,
      let summary = evaluationSummaryViewModel.summary
    {
      NavigationLink {
        EvaluationSummaryView(summary: summary) {
          evaluationSummaryViewModel.markRead()
        }
      } label: {
        cardLabel(
          icon: "doc.text", title: "教练评估",
          summary: summary.trainingPlanExcerpt, locked: false
        )
      }
    } else {
      evaluationPlaceholderRow
    }
  }

  private func editableRow(
    _ kind: ProfileCardKind,
    icon: String,
    title: String,
    summary: () -> String
  ) -> some View {
    NavigationLink {
      ProfileCardEditView(kind: kind, profile: profile, viewModel: viewModel)
    } label: {
      cardLabel(icon: icon, title: title, summary: summary(), locked: false)
    }
  }

  /// Read-only presentation (spec 032 D2: the only V0.1b lock — matches the
  /// backend's 403 ONE_RM_LOCKED真 gate; coach edits arrive with 033).
  private var oneRMRow: some View {
    VStack(alignment: .leading, spacing: MeetPRSpacing.xs) {
      cardLabel(
        icon: "scalemass", title: "我的极限",
        summary: OnboardingSummaryFormatter.oneRM(profile), locked: true)
      Text("🔒 已锁定,联系教练修改")
        .font(Font.MeetPR.caption)
        .foregroundStyle(Color.MeetPR.fgTertiary)
    }
  }

  /// 033 seam: GET evaluation-summary + detail page replace this row.
  private var evaluationPlaceholderRow: some View {
    cardLabel(
      icon: "doc.text", title: "教练评估",
      summary: "教练完成评估后,可在这里查看评估总结", locked: false
    )
    .opacity(0.5)
  }

  private func cardLabel(
    icon: String, title: String, summary: String, locked: Bool
  ) -> some View {
    HStack(spacing: MeetPRSpacing.md) {
      Image(systemName: icon)
        .font(.system(size: 18))
        .frame(width: 28)
        .foregroundStyle(Color.MeetPR.fgSecondary)
      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: MeetPRSpacing.xs) {
          Text(title)
            .font(Font.MeetPR.bodyEmphasis)
            .foregroundStyle(Color.MeetPR.fgPrimary)
          if locked {
            Image(systemName: "lock.fill")
              .font(.system(size: 11))
              .foregroundStyle(Color.MeetPR.fgTertiary)
          }
        }
        Text(summary)
          .font(Font.MeetPR.caption)
          .foregroundStyle(Color.MeetPR.fgSecondary)
          .lineLimit(1)
      }
    }
  }
}

/// Which archive card is being edited; maps onto the step patch builders
/// (1RM card deliberately has no kind — the lock is structural, risk 6).
enum ProfileCardKind {
  case basics, background, environment, recovery, materials, competition, injuries

  /// The wizard step whose patch builder saves this card. Never 3.
  var patchStep: Int {
    switch self {
    case .basics: 1
    case .background: 2
    case .environment: 4
    case .recovery: 5
    case .materials: 6
    case .competition, .injuries: 7
    }
  }

  var title: String {
    switch self {
    case .basics: "基础信息"
    case .background: "训练背景"
    case .environment: "训练环境"
    case .recovery: "恢复能力"
    case .materials: "训练资料"
    case .competition: "比赛/备注"
    case .injuries: "伤病记录"
    }
  }
}

/// Push-in edit page: a local draft copy seeded from the profile, the
/// card's field section (the SAME views the wizard renders — no drift), and
/// an explicit save (spec 032 §7).
@available(iOS 17.0, macOS 14.0, *)
struct ProfileCardEditView: View {
  let kind: ProfileCardKind
  let viewModel: MyProfileViewModel
  @State private var draft: OnboardingDraft
  @State private var isSaving = false
  @Environment(\.dismiss) private var dismiss

  init(kind: ProfileCardKind, profile: OnboardingProfile, viewModel: MyProfileViewModel) {
    self.kind = kind
    self.viewModel = viewModel
    self._draft = State(initialValue: OnboardingDraft.from(profile))
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: MeetPRSpacing.lg) {
        fields
        if let saveError = viewModel.saveError {
          Text(saveError)
            .font(Font.MeetPR.caption)
            .foregroundStyle(Color.MeetPR.brandRed)
        }
        PrimaryButton("保存", isLoading: isSaving, isFullWidth: true) {
          Task { await save() }
        }
      }
      .padding(MeetPRSpacing.base)
    }
    .scrollContentBackground(.hidden)
    .background(Color.MeetPR.bg)
    .navigationTitle(kind.title)
  }

  @ViewBuilder
  private var fields: some View {
    switch kind {
    case .basics:
      Step1BasicsSection(draft: $draft)
    case .background:
      Step2BackgroundSection(draft: $draft)
    case .environment:
      Step4EnvironmentSection(draft: $draft)
    case .recovery:
      Step5RecoverySection(draft: $draft)
    case .materials:
      Step6MaterialsSection(draft: $draft)
    case .competition:
      CompetitionFieldsSection(draft: $draft)
    case .injuries:
      InjuryFieldsSection(draft: $draft)
    }
  }

  private func save() async {
    isSaving = true
    defer { isSaving = false }
    // patchStep is never 3 → 1RM fields physically absent from every
    // card-edit PUT (spec 032 risk 6 + grep acceptance).
    if await viewModel.save(draft.patch(forStep: kind.patchStep)) {
      dismiss()
    }
  }
}
