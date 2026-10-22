import CoreModels
import Foundation
import Networking
import Observation
import RepositoryContracts
import SwiftUI

/// Launch-only fixture host; the normal coach Demo route is unchanged.
@MainActor
public struct CoachFlexibleDayDemoView: View {
  /// Regression fixture injection through the real app root, not a replacement screen.
  public static func launchHangRepositories() -> (
    plans: any PlanRepository, studentPlans: any StudentPlanRepository
  ) {
    let repository = CoachFlexibleDayDemoRepository(
      fixture: CoachFlexibleDayDemoFixture(now: Date()))
    return (repository, repository)
  }

  @State private var state = CoachFlexibleDayDemoState()
  @Environment(\.dynamicTypeSize) private var dynamicTypeSize

  public init() {}

  public var body: some View {
    Group {
      if ProcessInfo.processInfo.arguments.contains("-spec092-coach-day") {
        NavigationStack {
          CoachDayDetailView(day: state.repository.detailDay)
        }
      } else {
        StudentRosterView(
          viewModel: state.roster, rows: state.rows, now: state.now,
          context: state.context, loadsOnAppear: false)
      }
    }
    .environment(\.coachNow, state.now)
    .dynamicTypeSize(
      ProcessInfo.processInfo.arguments.contains("-spec092-accessibility-large")
        ? .accessibility2 : dynamicTypeSize
    )
    .preferredColorScheme(
      ProcessInfo.processInfo.arguments.contains("-spec092-dark") ? .dark : .light)
  }
}

@Observable
@MainActor
private final class CoachFlexibleDayDemoState {
  let repository: CoachFlexibleDayDemoRepository
  let context: CoachStudentDetailContext
  let rows: [StudentRosterRowModel]
  let roster: StudentRosterViewModel
  let now: Date

  init() {
    let now = Date()
    let fixture = CoachFlexibleDayDemoFixture(now: now)
    let repository = CoachFlexibleDayDemoRepository(fixture: fixture)
    self.now = now
    self.repository = repository
    self.context = Self.context(repository)
    roster = StudentRosterViewModel(
      students: repository, plans: repository, trainingLogs: EmptyStudentTrainingLogRepository(),
      feedback: EmptyStudentFeedbackRepository())
    rows = fixture.students.map { student in
      StudentRosterViewModel.makeRow(
        summary: student, plan: fixture.plans[student.id],
        coachLogs: fixture.logs.filter { $0.studentID == student.id }, feedback: [], now: now)
    }
  }

  private static func context(_ repository: CoachFlexibleDayDemoRepository)
    -> CoachStudentDetailContext
  {
    CoachStudentDetailContext(
      plans: repository, trainingLogs: EmptyStudentTrainingLogRepository(),
      feedback: EmptyStudentFeedbackRepository(), evaluations: InMemoryCoachEvaluationRepository(),
      summaries: InMemoryCoachEvaluationSummaryRepository(coachId: UUID()),
      profiles: InMemoryCoachStudentProfileReader(), videos: InMemoryCoachStudentVideoRepository(),
      readiness: EmptyReadinessRepository(), exerciseStats: InMemoryCoachExerciseStatsRepository(),
      planning: repository, draftStore: DraftStore.shared)
  }

}

/// Real detail/roster consumers read these fixtures through the coach repository seam.
actor CoachFlexibleDayDemoRepository: PlanRepository, StudentPlanRepository {
  nonisolated let detailDay: StudentExecutionDay
  nonisolated let students: [CoachStudentSummary]
  private let plans: [UUID: StudentPlanView]
  private var logs: [CoachSetLogDTO]

  fileprivate init(fixture: CoachFlexibleDayDemoFixture) {
    detailDay = fixture.detailDay
    students = fixture.students
    plans = fixture.plans
    logs = fixture.logs
  }

  func fetchStudents() -> [CoachStudentSummary] { students }
  func fetchMainLiftCatalog() -> [Exercise] { InMemoryPlanRepository.syntheticCompetitionLifts() }
  func fetchAccessoryExercises(filters: AccessoryFilters) -> [Exercise] {
    InMemoryPlanRepository.loadBundledCatalogV2()
  }
  func publishPlan(plan: TrainingPlan, days: [PlanDay], exercises: [PlanExercise], sets: [PlanSet])
  {}
  func fetchCurrentPlan(studentID: UUID) -> StudentPlanView? { plans[studentID] }
  func fetchDay(studentID: UUID, date: Date) -> StudentPlanDay? {
    plans[studentID]?.days.first { CoachFeatureCalendar.isSameDay($0.date, date) }
  }
  func fetchCycleDays(studentID: UUID) -> [StudentPlanDay] { plans[studentID]?.days ?? [] }
  func fetchCoachLogs(studentID: UUID, in range: ClosedRange<Date>) -> [CoachSetLogDTO]? {
    logs.filter { $0.studentID == studentID && range.contains($0.loggedAt) }
  }
  func replaceLogs(_ logs: [CoachSetLogDTO]) { self.logs = logs }
}

private struct CoachFlexibleDayDemoFixture {
  let students: [CoachStudentSummary]
  let plans: [UUID: StudentPlanView]
  let logs: [CoachSetLogDTO]
  let detailDay: StudentExecutionDay

  init(now: Date) {
    let calendar = CoachFeatureCalendar.calendar
    let monday = CoachWeekOverview.week(containing: now).dates.first ?? now
    let catalog = InMemoryPlanRepository.loadBundledCatalogV2()
    let main =
      InMemoryPlanRepository.syntheticCompetitionLifts().first { $0.competitionStance == .sumo }
      ?? InMemoryPlanRepository.syntheticCompetitionLifts()[0]
    let accessory =
      catalog.first { $0.name == "哑铃弯举" }
      ?? catalog.first { $0.exerciseType == .accessory } ?? main
    let jumperID = UUID()
    let laggingID = UUID()
    students = Self.students(jumperID: jumperID, laggingID: laggingID)
    func date(_ offset: Int) -> Date {
      calendar.date(byAdding: .day, value: offset, to: monday) ?? monday
    }
    func day(_ offset: Int, week: Int, completed: Bool = false) -> StudentPlanDay {
      StudentPlanDay(
        id: UUID(), weekNumber: week, dayOfWeek: (offset % 7 + 7) % 7 + 1,
        date: date(offset), completedAt: completed ? date(1) : nil,
        exercises: [
          StudentPlanExercise(
            id: UUID(), exercise: main, sequenceIndex: 0,
            prescribedSets: (0..<4).map {
              PrescribedSet(id: UUID(), setIndex: $0, weightKg: 200, reps: 3, rpe: 8)
            })
        ])
    }
    let jumpDays = [
      day(0, week: 2, completed: true), day(1, week: 2),
      day(3, week: 2), day(5, week: 2, completed: true),
    ]
    let later = jumpDays[3]
    let jumpLogs = Self.jumpLogs(
      studentID: jumperID, day: later, accessory: accessory, date: date(1))
    let lagDays = [day(-14, week: 2), day(-13, week: 2), day(0, week: 4), day(1, week: 4)]
    let lagLogs = (0..<2).map { index in
      CoachSetLogDTO(
        id: UUID(), studentID: laggingID, planExerciseID: lagDays[index].exercises.first?.id,
        setIndex: 0, weightKg: 180, reps: 3, completed: true,
        loggedAt: date(index).addingTimeInterval(12 * 3_600))
    }
    plans = [
      jumperID: StudentPlanView(cycleID: UUID(), weekIndex: 2, startDate: date(-7), days: jumpDays),
      laggingID: StudentPlanView(
        cycleID: UUID(), weekIndex: 4, startDate: date(-21), days: lagDays),
    ]
    logs = jumpLogs + lagLogs
    detailDay = StudentExecutionDay(
      date: later.date, planDay: later, allLogs: jumpLogs, planDays: jumpDays)
  }

  private static func students(jumperID: UUID, laggingID: UUID) -> [CoachStudentSummary] {
    [
      CoachStudentSummary(id: jumperID, displayName: "Demo · D4", status: .active),
      CoachStudentSummary(id: laggingID, displayName: "Demo · W2 → W4", status: .active),
    ]
  }

  private static func jumpLogs(
    studentID: UUID, day: StudentPlanDay, accessory: Exercise, date: Date
  ) -> [CoachSetLogDTO] {
    return
      (0..<5).map { index in
        CoachSetLogDTO(
          id: UUID(), studentID: studentID, planExerciseID: day.exercises.first?.id,
          setIndex: index, weightKg: index == 4 ? 180 : 200, reps: 3, rpe: 7.5,
          completed: true, loggedAt: date.addingTimeInterval(12 * 3_600))
      }
      + (0..<2).map { index in
        CoachSetLogDTO(
          id: UUID(), studentID: studentID, planExerciseID: nil, planDayID: day.id,
          adhoc: true, exerciseID: accessory.id, setIndex: index, weightKg: 12.5, reps: 12,
          completed: true, loggedAt: date.addingTimeInterval(13 * 3_600))
      }
  }
}
