import DesignSystem
import RepositoryContracts
import SwiftUI

@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct StudentRosterView: View {
  @Bindable private var viewModel: StudentRosterViewModel
  @Bindable private var queueViewModel: BindQueueViewModel
  private let rows: [StudentRosterRowModel]?
  private let context: CoachStudentDetailContext
  private let profiles: any OnboardingProfileReading
  private let onAccepted: (String) async -> Void
  private let loadsOnAppear: Bool
  private let now: Date
  @State private var acceptTarget: CoachBindRequestItem?
  @State private var rejectTarget: CoachBindRequestItem?
  @State private var profileTarget: CoachBindRequestItem?

  init(
    viewModel: StudentRosterViewModel,
    queueViewModel: BindQueueViewModel = BindQueueViewModel(
      repository: InMemoryCoachBindQueueRepository(coachId: UUID())
    ),
    rows: [StudentRosterRowModel]? = nil,
    now: Date,
    context: CoachStudentDetailContext,
    profiles: any OnboardingProfileReading = InMemoryCoachStudentProfileReader(),
    onAccepted: @escaping (String) async -> Void = { _ in },
    chat _: CoachChatContext? = nil,
    loadsOnAppear: Bool = true
  ) {
    self.viewModel = viewModel
    self.queueViewModel = queueViewModel
    self.rows = rows
    self.now = now
    self.context = context
    self.profiles = profiles
    self.onAccepted = onAccepted
    self.loadsOnAppear = loadsOnAppear
  }

  var body: some View {
    NavigationStack {
      StudentRosterContent(
        searchText: $viewModel.searchText,
        loadState: rows == nil ? viewModel.state : .loaded,
        applications: sortedApplications,
        rows: rows ?? viewModel.filteredRows,
        now: now,
        context: context,
        onAccept: { acceptTarget = $0 },
        onViewProfile: { profileTarget = $0 },
        onReject: { rejectTarget = $0 },
        onEvaluationCompleted: { viewModel.markStudentActive($0) },
        onRefresh: {
          async let rosterRefresh: Void = viewModel.refresh()
          async let queueRefresh: Void = queueViewModel.refresh()
          _ = await (rosterRefresh, queueRefresh)
        }
      )
      .hideNavigationBar()
      .navigationDestination(item: $profileTarget) { item in
        StudentOnboardingProfileView(
          item: item,
          profiles: profiles,
          onAccept: { acceptTarget = item },
          onReject: { rejectTarget = item }
        )
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color.MeetPR.bgBase)
    .overlay {
      if case .failed(let message) = viewModel.state {
        ContentUnavailableView(
          CoachRosterStrings.loadFailed,
          systemImage: "exclamationmark.triangle",
          description: Text(message)
        )
        .background(Color.MeetPR.bgBase)
      }
    }
    .sheet(item: $acceptTarget) { item in
      AcceptBindRequestSheet(studentName: item.displayName) { skipEvaluation, skipReason in
        let accepted = await queueViewModel.accept(
          item,
          skipEvaluation: skipEvaluation,
          skipReason: skipReason
        )
        if accepted {
          profileTarget = nil
          await onAccepted(item.displayName)
        }
        return accepted
      }
    }
    .confirmationDialog(
      CoachRosterStrings.rejectConfirmation,
      isPresented: rejectDialogBinding,
      titleVisibility: .visible
    ) {
      Button(CoachRosterStrings.reject, role: .destructive) {
        if let item = rejectTarget {
          Task {
            if await queueViewModel.reject(item) {
              profileTarget = nil
            }
          }
        }
      }
      Button(CoachRosterStrings.cancel, role: .cancel) {}
    }
    .alert(
      queueViewModel.bannerMessage ?? "",
      isPresented: queueErrorBinding
    ) {
      Button(CoachRosterStrings.confirmation, role: .cancel) {
        queueViewModel.bannerMessage = nil
      }
    }
    .task {
      guard loadsOnAppear else { return }
      await viewModel.loadIfNeeded()
      await queueViewModel.loadIfNeeded()
    }
  }

  private var sortedApplications: [CoachBindRequestItem] {
    queueViewModel.items.sorted { $0.submittedAt > $1.submittedAt }
  }

  private var rejectDialogBinding: Binding<Bool> {
    Binding(
      get: { rejectTarget != nil },
      set: { isPresented in
        if !isPresented {
          rejectTarget = nil
        }
      }
    )
  }

  private var queueErrorBinding: Binding<Bool> {
    Binding(
      get: { queueViewModel.bannerMessage != nil },
      set: { isPresented in
        if !isPresented {
          queueViewModel.bannerMessage = nil
        }
      }
    )
  }
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
struct StudentRosterContent: View {
  @Binding var searchText: String
  let loadState: StudentRosterViewModel.LoadState
  let applications: [CoachBindRequestItem]
  let rows: [StudentRosterRowModel]
  let now: Date
  let context: CoachStudentDetailContext
  let onAccept: (CoachBindRequestItem) -> Void
  let onViewProfile: (CoachBindRequestItem) -> Void
  let onReject: (CoachBindRequestItem) -> Void
  let onEvaluationCompleted: (UUID) -> Void
  let onRefresh: () async -> Void

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: MeetPRSpacing.point14) {
        Text(CoachShellStrings.students)
          .font(.MeetPR.display(size: MeetPRFontMetrics.size34))
          .foregroundStyle(Color.MeetPR.textPrimary)

        CoachRosterSearchField(searchText: $searchText)

        if !applications.isEmpty {
          Text(CoachRosterStrings.newStudentRequests(applications.count))
            .font(.MeetPR.mono(size: MeetPRFontMetrics.size12))
            .foregroundStyle(Color.MeetPR.gold500)

          ForEach(applications) { item in
            CoachApplicationCard(
              item: item,
              now: now,
              onAccept: { onAccept(item) },
              onViewProfile: { onViewProfile(item) },
              onReject: { onReject(item) }
            )
          }
        }

        switch contentState {
        case .loading:
          ProgressView(CoachRosterStrings.loadingStudents)
            .tint(Color.MeetPR.gold500)
            .frame(maxWidth: .infinity)
            .padding(.vertical, MeetPRSpacing.point32)
            .accessibilityIdentifier("coach.roster.loading")
        case .emptyRoster:
          CoachRosterEmptyState(
            title: CoachRosterStrings.noStudents,
            description: CoachRosterStrings.noStudentsSubtitle,
            systemImage: "person.badge.plus"
          )
        case .noMatches:
          CoachRosterEmptyState(
            title: CoachRosterStrings.noMatchingStudents,
            description: nil,
            systemImage: "magnifyingglass"
          )
        case .rows:
          Text(CoachRosterStrings.activeStudents(activeRows.count))
            .font(.MeetPR.mono(size: MeetPRFontMetrics.size12))
            .foregroundStyle(Color.MeetPR.textTertiary)

          ForEach(activeRows) { row in
            studentLink(row)
          }

          if !abnormalRows.isEmpty {
            Text(CoachRosterStrings.abnormalStudents(abnormalRows.count))
              .font(.MeetPR.mono(size: MeetPRFontMetrics.size12))
              .foregroundStyle(Color.MeetPR.danger)
              .padding(.top, MeetPRSpacing.point2)

            ForEach(abnormalRows) { row in
              studentLink(row)
            }
          }
        }
      }
      .padding(.horizontal, MeetPRSpacing.pageHorizontal)
      .padding(.top, MeetPRSpacing.point6)
      .padding(.bottom, MeetPRSpacing.point28)
    }
    .scrollIndicators(.hidden)
    .refreshable {
      await onRefresh()
    }
  }

  private func studentLink(_ row: StudentRosterRowModel) -> some View {
    NavigationLink {
      StudentDetailView(
        summary: row.student,
        context: context,
        onEvaluationCompleted: { onEvaluationCompleted(row.id) }
      )
    } label: {
      StudentRosterRow(row: row, now: now)
    }
    .buttonStyle(PressScaleButtonStyle(scale: 0.97))
  }

  private var activeRows: [StudentRosterRowModel] {
    rows.filter { !isAbnormal($0) }
  }

  private var contentState: StudentRosterContentState {
    StudentRosterContentState.resolve(
      loadState: loadState,
      hasStudents: !rows.isEmpty,
      hasSearchQuery: !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    )
  }

  private var abnormalRows: [StudentRosterRowModel] {
    rows.filter(isAbnormal)
  }

  private func isAbnormal(_ row: StudentRosterRowModel) -> Bool {
    if !row.triageSignals.isEmpty {
      return true
    }
    if case .abnormal = row.student.status {
      return true
    }
    return false
  }
}

enum StudentRosterContentState: Equatable {
  case loading
  case emptyRoster
  case noMatches
  case rows

  static func resolve(
    loadState: StudentRosterViewModel.LoadState,
    hasStudents: Bool,
    hasSearchQuery: Bool
  ) -> StudentRosterContentState {
    switch loadState {
    case .idle, .loading:
      return .loading
    case .failed:
      return .rows
    case .loaded:
      if hasStudents { return .rows }
      return hasSearchQuery ? .noMatches : .emptyRoster
    }
  }
}

@available(iOS 17.0, macOS 14.0, *)
struct CoachRosterEmptyState: View {
  let title: String
  let description: String?
  let systemImage: String

  var body: some View {
    ContentUnavailableView {
      Label(title, systemImage: systemImage)
    } description: {
      if let description {
        Text(description)
      }
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, MeetPRSpacing.point28)
  }
}

@available(iOS 17.0, macOS 14.0, *)
private struct CoachRosterSearchField: View {
  @Binding var searchText: String

  var body: some View {
    HStack(spacing: MeetPRSpacing.point9) {
      Image(systemName: "magnifyingglass")
        .font(.MeetPR.system(size: MeetPRFontMetrics.size17))
        .foregroundStyle(Color.MeetPR.textDisabled)

      TextField(CoachRosterStrings.searchStudents, text: $searchText)
        .textFieldStyle(.plain)
        .font(.MeetPR.body(size: MeetPRFontMetrics.size14))
        .foregroundStyle(Color.MeetPR.textPrimary)
        .submitLabel(.search)

      if !searchText.isEmpty {
        Button {
          searchText = ""
        } label: {
          Image(systemName: "xmark.circle.fill")
            .font(.MeetPR.system(size: MeetPRFontMetrics.size15))
            .foregroundStyle(Color.MeetPR.textDisabled)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(CoachRosterStrings.clearSearch)
      }
    }
    .padding(.horizontal, MeetPRSpacing.point14)
    .padding(.vertical, MeetPRSpacing.space3)
    .background(Color.MeetPR.surfaceCard)
    .clipShape(.rect(cornerRadius: MeetPRRadius.control))
    .overlay {
      RoundedRectangle(cornerRadius: MeetPRRadius.control)
        .stroke(Color.MeetPR.borderDefault, lineWidth: MeetPRSpacing.point1)
    }
    .meetPRCardSurface(.card)
  }
}
