import CoreModels
import Foundation
import Observation
import RepositoryContracts

@Observable
@MainActor
@available(iOS 17.0, macOS 14.0, *)
final class PlanningWorkspaceViewModel {
  enum LoadState: Equatable, Sendable {
    var isFailure: Bool {
      if case .failed = self { return true }
      return false
    }

    case idle
    case loading
    case loaded
    case failed(String)
  }

  private static let maxConcurrentStudentLoads = 4
  static let recentPublishedLimit = 5

  private(set) var state: LoadState = .idle
  private(set) var draftRows: [PlanningDraftRowModel] = []
  private(set) var needsPlanningRows: [PlanningNeededRowModel] = []
  private(set) var recentPublishedRows: [PlanningPublishedRowModel] = []

  var hasWorkspaceContent: Bool {
    !draftRows.isEmpty || !needsPlanningRows.isEmpty || !recentPublishedRows.isEmpty
  }

  @ObservationIgnored private let repository: any PlanRepository
  @ObservationIgnored private let studentPlans: any StudentPlanRepository
  @ObservationIgnored private let draftStore: DraftStore
  @ObservationIgnored private let profiles: (any OnboardingProfileReading)?
  @ObservationIgnored private let now: @Sendable () -> Date
  @ObservationIgnored private let calendar: Calendar

  init(
    repository: any PlanRepository,
    studentPlans: any StudentPlanRepository,
    draftStore: DraftStore,
    profiles: (any OnboardingProfileReading)? = nil,
    now: @escaping @Sendable () -> Date = { Date() },
    calendar: Calendar = CoachFeatureCalendar.calendar
  ) {
    self.repository = repository
    self.studentPlans = studentPlans
    self.draftStore = draftStore
    self.profiles = profiles
    self.now = now
    self.calendar = calendar
  }

  func loadIfNeeded() async {
    guard state == .idle || state.isFailure else { return }
    await refresh()
  }

  func refresh() async {
    state = .loading
    do {
      let students = try await repository.fetchStudents()
      let drafts = loadDraftRows(for: students)
      draftRows = drafts
      let loaded = await loadPlanRows(for: students, draftIDs: Set(drafts.map(\.id)))
      needsPlanningRows = loaded.needsPlanning
      recentPublishedRows = loaded.recentPublished
      state = .loaded
    } catch {
      draftRows = []
      needsPlanningRows = []
      recentPublishedRows = []
      state = .failed(PlanningWorkspaceStrings.text("coach.workspace.error.load"))
    }
  }

  private func loadDraftRows(for students: [CoachStudentSummary]) -> [PlanningDraftRowModel] {
    students.compactMap(draftRow).sorted { $0.lastSavedAt > $1.lastSavedAt }
  }

  private func draftRow(for student: CoachStudentSummary) -> PlanningDraftRowModel? {
    guard let draft = try? draftStore.loadDraft(traineeID: student.id) else { return nil }
    let name = draft.name.trimmingCharacters(in: .whitespacesAndNewlines)
    return PlanningDraftRowModel(
      student: student,
      summary: PlanningWorkspaceSummary.draftProgressSummary(
        name: name.isEmpty
          ? student.displayName
          : PlanningWorkspaceStrings.displayDraftName(name, studentName: student.displayName),
        currentStepRawValue: draft.currentStepRawValue,
        planWeeks: draft.planWeeks
      ),
      lastSavedAt: draft.lastSavedAt
    )
  }

  private func loadPlanRows(
    for students: [CoachStudentSummary],
    draftIDs: Set<UUID>
  ) async -> PlanningWorkspaceRows {
    let results = await loadStudentRows(for: students)
    return PlanningWorkspaceRows(
      needsPlanning: results.compactMap(\.need).filter { !draftIDs.contains($0.id) },
      recentPublished: Array(
        results
          .compactMap(\.recent)
          .sorted { $0.proxyPublishedAt > $1.proxyPublishedAt }
          .prefix(Self.recentPublishedLimit)
      )
    )
  }

  private func loadStudentRows(
    for students: [CoachStudentSummary]
  ) async -> [PlanningWorkspaceStudentRows] {
    let studentPlans = self.studentPlans
    let profiles = self.profiles
    let timestamp = now()
    let calendar = self.calendar

    return await withTaskGroup(of: (Int, PlanningWorkspaceStudentRows).self) { group in
      var iterator = students.enumerated().makeIterator()
      func submitNext() {
        guard let (index, student) = iterator.next() else { return }
        group.addTask {
          let rows = await PlanningWorkspaceStudentLoader.load(
            student: student,
            studentPlans: studentPlans,
            profiles: profiles,
            now: timestamp,
            calendar: calendar
          )
          return (index, rows)
        }
      }

      for _ in 0..<Self.maxConcurrentStudentLoads { submitNext() }
      var ordered = [PlanningWorkspaceStudentRows?](repeating: nil, count: students.count)
      for await (index, rows) in group {
        ordered[index] = rows
        submitNext()
      }
      return ordered.compactMap { $0 }
    }
  }
}

private struct PlanningWorkspaceRows: Sendable {
  let needsPlanning: [PlanningNeededRowModel]
  let recentPublished: [PlanningPublishedRowModel]
}

private struct PlanningWorkspaceStudentRows: Sendable {
  let need: PlanningNeededRowModel?
  let recent: PlanningPublishedRowModel?
}

private enum PlanningWorkspaceStudentLoader {
  static func load(
    student: CoachStudentSummary,
    studentPlans: any StudentPlanRepository,
    profiles: (any OnboardingProfileReading)?,
    now: Date,
    calendar: Calendar
  ) async -> PlanningWorkspaceStudentRows {
    let plan: StudentPlanView?
    do {
      plan = try await studentPlans.fetchCurrentPlan(studentID: student.id)
    } catch {
      return PlanningWorkspaceStudentRows(need: nil, recent: nil)
    }

    guard let plan else {
      return PlanningWorkspaceStudentRows(
        need: await needRow(student: student, reason: .noCurrentPlan, profiles: profiles),
        recent: nil
      )
    }

    let cycleDays = (try? await studentPlans.fetchCycleDays(studentID: student.id)) ?? []
    let reason = PlanningWorkspaceSummary.planNeedReason(
      plan: plan,
      cycleDays: cycleDays,
      now: now,
      calendar: calendar
    )
    let need: PlanningNeededRowModel?
    if let reason {
      need = await needRow(student: student, reason: reason, profiles: profiles)
    } else {
      need = nil
    }
    let recent = recentRow(
      student: student,
      plan: plan,
      cycleDays: cycleDays,
      calendar: calendar
    )
    return PlanningWorkspaceStudentRows(need: need, recent: recent)
  }

  private static func needRow(
    student: CoachStudentSummary,
    reason: PlanningPlanNeedReason,
    profiles: (any OnboardingProfileReading)?
  ) async -> PlanningNeededRowModel {
    PlanningNeededRowModel(
      student: student,
      reason: reason,
      summary: reason.title,
      profile: await profile(for: student.id, profiles: profiles)
    )
  }

  private static func recentRow(
    student: CoachStudentSummary,
    plan: StudentPlanView,
    cycleDays: [StudentPlanDay],
    calendar: Calendar
  ) -> PlanningPublishedRowModel? {
    guard
      let weeks = PlanningWorkspaceSummary.cycleWeekCount(
        cycleDays: cycleDays,
        calendar: calendar
      )
    else { return nil }

    return PlanningPublishedRowModel(
      student: student,
      summary: PlanningWorkspaceSummary.publishedSummary(plan: plan, weeks: weeks),
      proxyPublishedAt: plan.startDate
    )
  }

  private static func profile(
    for studentID: UUID,
    profiles: (any OnboardingProfileReading)?
  ) async -> OnboardingProfile? {
    guard let profiles else { return nil }
    return try? await profiles.fetchProfile(studentId: studentID)
  }
}
