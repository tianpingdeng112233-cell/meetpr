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
    Section(StudentStrings.localized(.profileCardsSection001)) {
      editableRow(
        .basics, icon: "person.text.rectangle",
        title: StudentStrings.localized(.profileCardsSection002)
      ) {
        OnboardingSummaryFormatter.basics(profile)
      }
      editableRow(
        .background, icon: "figure.strengthtraining.traditional",
        title: StudentStrings.localized(.profileCardsSection003)
      ) {
        OnboardingSummaryFormatter.background(profile)
      }
      oneRMRow
      editableRow(
        .environment, icon: "calendar", title: StudentStrings.localized(.profileCardsSection004)
      ) {
        OnboardingSummaryFormatter.environment(profile)
      }
      editableRow(
        .recovery, icon: "bed.double", title: StudentStrings.localized(.profileCardsSection005)
      ) {
        OnboardingSummaryFormatter.recovery(profile)
      }
      editableRow(
        .materials, icon: "folder", title: StudentStrings.localized(.profileCardsSection006)
      ) {
        OnboardingSummaryFormatter.materials(profile)
      }
      editableRow(
        .competition, icon: "target", title: StudentStrings.localized(.meetTitle)
      ) {
        OnboardingSummaryFormatter.competition(profile)
      }
      editableRow(.note, icon: "text.bubble", title: StudentStrings.localized(.profileNote)) {
        OnboardingSummaryFormatter.note(profile)
      }
      editableRow(
        .injuries, icon: "bandage", title: StudentStrings.localized(.profileCardsSection008)
      ) {
        OnboardingSummaryFormatter.injuries(profile)
      }
      evaluationRow
    }
    .listRowBackground(Color.MeetPR.surfaceCard)
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
          icon: "doc.text", title: StudentStrings.localized(.profileCardsSection009),
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
        icon: "scalemass", title: StudentStrings.localized(.profileCardsSection010),
        summary: OnboardingSummaryFormatter.oneRM(profile), locked: true)
      Text(StudentStrings.localized(.profileCardsSection011))
        .font(.MeetPR.body(size: MeetPRFontMetrics.size11, weight: .medium))
        .foregroundStyle(Color.MeetPR.textMuted)
    }
  }

  /// 033 seam: GET evaluation-summary + detail page replace this row.
  private var evaluationPlaceholderRow: some View {
    cardLabel(
      icon: "doc.text", title: StudentStrings.localized(.profileCardsSection009),
      summary: StudentStrings.localized(.profileCardsSection012), locked: false
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
        .foregroundStyle(Color.MeetPR.textMuted)
      VStack(alignment: .leading, spacing: 2) {
        HStack(spacing: MeetPRSpacing.xs) {
          Text(title)
            .font(.MeetPR.body(size: MeetPRFontMetrics.size16, weight: .semibold))
            .foregroundStyle(Color.MeetPR.textPrimary)
          if locked {
            Image(systemName: "lock.fill")
              .font(.system(size: 11))
              .foregroundStyle(Color.MeetPR.textMuted)
          }
        }
        Text(summary)
          .font(.MeetPR.body(size: MeetPRFontMetrics.size11, weight: .medium))
          .foregroundStyle(Color.MeetPR.textMuted)
          .lineLimit(1)
      }
    }
  }
}

/// Which archive card is being edited; maps onto the step patch builders
/// (1RM card deliberately has no kind — the lock is structural, risk 6).
enum ProfileCardKind: Hashable {
  case basics, weight, background, environment, recovery, materials, competition, note, injuries

  /// The wizard step whose patch builder saves this card. Never 3.
  var patchStep: Int {
    switch self {
    case .basics, .weight: 1
    case .background: 2
    case .environment: 4
    case .recovery: 5
    case .materials: 6
    case .competition, .note, .injuries: 7
    }
  }

  var title: String {
    switch self {
    case .basics: StudentStrings.localized(.profileCardsSection002)
    case .background: StudentStrings.localized(.profileCardsSection003)
    case .environment: StudentStrings.localized(.profileCardsSection004)
    case .recovery: StudentStrings.localized(.profileCardsSection005)
    case .materials: StudentStrings.localized(.profileCardsSection006)
    case .competition: StudentStrings.localized(.meetTitle)
    case .weight: StudentStrings.localized(.dashboardProfileMetricsView001)
    case .note: StudentStrings.localized(.profileNote)
    case .injuries: StudentStrings.localized(.profileCardsSection008)
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
  @State private var showsValidation = false
  @State private var confirmsRemoval = false
  private let hasMeet: Bool
  @Environment(\.dismiss) private var dismiss

  init(kind: ProfileCardKind, profile: OnboardingProfile, viewModel: MyProfileViewModel) {
    self.kind = kind
    self.viewModel = viewModel
    self.hasMeet = profile.isCompeting == true && profile.competitionDate != nil
    var initial = OnboardingDraft.from(profile)
    if kind == .competition {
      if !hasMeet { initial.competitionDate = DateOnly.string(from: Date()) }
      initial.isCompeting = true
    }
    self._draft = State(initialValue: initial)
  }

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: MeetPRSpacing.lg) {
        fields
        if showsValidation {
          Text(
            StudentStrings.localized(
              kind == .competition ? .meetChooseClass : .myProfileViewModel002)
          )
          .font(.MeetPR.body(size: MeetPRFontMetrics.size13))
          .foregroundStyle(Color.MeetPR.dangerMuted)
        }
        if let saveError = viewModel.saveError {
          Text(saveError)
            .font(.MeetPR.body(size: MeetPRFontMetrics.size11, weight: .medium))
            .foregroundStyle(Color.MeetPR.dangerMuted)
        }
        GoldCTA(
          StudentStrings.localized(.profileCardsSection013),
          sub: nil,
          icon: .none,
          isLoading: isSaving
        ) {
          Task { await save() }
        }
        if kind == .competition, hasMeet {
          Button(role: .destructive) {
            confirmsRemoval = true
          } label: {
            Text(StudentStrings.localized(.meetRemove))
              .foregroundStyle(Color.MeetPR.dangerMuted)
          }
          .frame(maxWidth: .infinity, minHeight: MeetPRSpacing.minimumHitTarget)
          .disabled(isSaving)
        }
      }
      .padding(MeetPRSpacing.base)
    }
    .scrollContentBackground(.hidden)
    .background(Color.MeetPR.bgBase)
    .navigationTitle(kind.title)
    .alert(StudentStrings.localized(.meetConfirmRemove), isPresented: $confirmsRemoval) {
      Button(StudentStrings.localized(.meetRemoveAction), role: .destructive) {
        Task { await removeMeet() }
      }
      Button(StudentStrings.localized(.accountSecuritySheets013), role: .cancel) {}
    }
  }

  @ViewBuilder
  private var fields: some View {
    switch kind {
    case .basics:
      Step1BasicsSection(draft: $draft, highlighted: showsValidation ? ["weight_kg"] : [])
    case .weight:
      BodyWeightField(
        kilograms: $draft.weightKg, unit: draft.unitPreference ?? .kg,
        labelKey: .bodyWeightLabel,
        isHighlighted: showsValidation, showsHelp: true)
    case .note:
      NoteToCoachFieldsSection(note: $draft.noteToCoach)
    case .background:
      Step2BackgroundSection(draft: $draft)
    case .environment:
      Step4EnvironmentSection(draft: $draft)
    case .recovery:
      Step5RecoverySection(draft: $draft)
    case .materials:
      Step6MaterialsSection(draft: $draft)
    case .competition:
      MeetFieldsSection(draft: $draft, showsErrors: showsValidation)
    case .injuries:
      InjuryFieldsSection(draft: $draft)
    }
  }

  private func removeMeet() async {
    guard !isSaving else { return }
    isSaving = true
    defer { isSaving = false }
    var removed = draft
    removed.isCompeting = false
    removed.competitionDate = nil
    removed.targetWeightClass = ""
    if await viewModel.save(removed.profilePatch(for: .competition)) { dismiss() }
  }

  private func save() async {
    guard !isSaving else { return }
    if (kind == .competition && !draft.isStepComplete(7))
      || ((kind == .weight || kind == .basics) && draft.weightKg == nil)
    {
      showsValidation = true
      return
    }
    showsValidation = false
    isSaving = true
    defer { isSaving = false }
    // patchStep is never 3 → 1RM fields physically absent from every
    // card-edit PUT (spec 032 risk 6 + grep acceptance).
    if await viewModel.save(draft.profilePatch(for: kind)) {
      dismiss()
    }
  }
}
