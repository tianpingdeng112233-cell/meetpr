import CoreModels
import Foundation
import RepositoryContracts
import Testing

@testable import StudentKit

// Spec 045 slice 4: solo session driver — day-locked adhoc commits, set_index
// continuation, 「重复上次」 prefill and picker suggestions.

private let student = UUID()
private let squatID = UUID()
private let benchID = UUID()

private let shanghai: Calendar = {
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
  return calendar
}()

private func shanghaiDate(_ iso: String) -> Date {
  ISO8601DateFormatter().date(from: iso) ?? Date(timeIntervalSince1970: 0)
}

private func seededLog(
  exerciseID: UUID,
  loggedDate: String,
  setIndex: Int,
  weight: Decimal = 100,
  reps: Int = 5,
  rpe: Decimal? = 8,
  loggedAtISO: String
) -> StudentSetLog {
  StudentSetLog(
    id: UUID(),
    studentID: student,
    planExerciseID: nil,
    exerciseID: exerciseID,
    loggedDate: loggedDate,
    adhoc: true,
    setIndex: setIndex,
    loggedAt: shanghaiDate(loggedAtISO),
    weightKg: weight,
    reps: reps,
    rpe: rpe,
    completed: true
  )
}

private func catalog() -> [Exercise] {
  [
    Exercise(
      id: squatID, name: "低杠位深蹲", nameEn: "Low-Bar Squat", exerciseType: .mainLift,
      mainLiftFamily: .squat, isCompetitionLift: true, muscleGroups: [.quad],
      equipment: [.barbell], createdAt: Date(timeIntervalSince1970: 0)),
    Exercise(
      id: benchID, name: "竞技卧推", nameEn: "Competition Bench", exerciseType: .mainLift,
      mainLiftFamily: .bench, isCompetitionLift: true, muscleGroups: [.chest],
      equipment: [.barbell], createdAt: Date(timeIntervalSince1970: 0)),
  ]
}

/// A mutable clock the test can move across midnight mid-session.
private final class Clock: @unchecked Sendable {
  var current: Date
  init(_ date: Date) { self.current = date }
}

@available(iOS 17.0, macOS 14.0, *)
@MainActor
private func makeViewModel(
  seed: [StudentSetLog] = [],
  clock: Clock
) -> (SoloSessionViewModel, InMemoryStudentTrainingLogRepository) {
  let logs = InMemoryStudentTrainingLogRepository(seed: seed)
  let viewModel = SoloSessionViewModel(
    studentID: student,
    logs: logs,
    e1rm: InMemoryE1RMRepository(),
    catalog: catalog(),
    now: { clock.current },
    calendar: shanghai
  )
  return (viewModel, logs)
}

@available(iOS 17.0, macOS 14.0, *)
@MainActor
@Test func sessionDayLocksAtLoadAcrossMidnight() async throws {
  // 23:30 Beijing on July 4 (15:30 UTC).
  let clock = Clock(shanghaiDate("2026-07-04T15:30:00Z"))
  let (viewModel, logs) = makeViewModel(clock: clock)
  await viewModel.load()
  #expect(viewModel.sessionDate == "2026-07-04")

  viewModel.addExercise(squatID)
  let draft = try #require(viewModel.drafts.first)
  viewModel.updateDraft(id: draft.id, weightKg: 140, reps: 5)

  // The lifter crosses midnight mid-session (00:10 Beijing = 16:10 UTC).
  clock.current = shanghaiDate("2026-07-04T16:10:00Z")
  await viewModel.commit(id: draft.id)

  let range = shanghaiDate("2026-07-01T00:00:00Z")...shanghaiDate("2026-07-31T00:00:00Z")
  let rows = try await logs.fetchLogs(studentID: student, in: range, scope: .all)
  #expect(rows.count == 1)
  #expect(rows.first?.loggedDate == "2026-07-04")
}

@available(iOS 17.0, macOS 14.0, *)
@MainActor
@Test func setIndexContinuesFromTodayExistingRows() async throws {
  let clock = Clock(shanghaiDate("2026-07-04T10:00:00Z"))
  let seed = [
    seededLog(
      exerciseID: squatID, loggedDate: "2026-07-04", setIndex: 0,
      loggedAtISO: "2026-07-04T08:00:00Z"),
    seededLog(
      exerciseID: squatID, loggedDate: "2026-07-04", setIndex: 1,
      loggedAtISO: "2026-07-04T08:05:00Z"),
  ]
  let (viewModel, logs) = makeViewModel(seed: seed, clock: clock)
  await viewModel.load()

  // 继续训练: today's committed rows show up already done.
  #expect(viewModel.drafts.count == 2)
  let allCompleted = viewModel.drafts.allSatisfy(\.completed)
  #expect(allCompleted)

  viewModel.addSet(for: squatID)
  let added = try #require(viewModel.drafts.last)
  #expect(added.weightKg == 100)  // prefilled from the previous squat row
  viewModel.updateDraft(id: added.id, weightKg: 105, reps: 3)
  await viewModel.commit(id: added.id)

  let range = shanghaiDate("2026-07-01T00:00:00Z")...shanghaiDate("2026-07-31T00:00:00Z")
  let rows = try await logs.fetchLogs(studentID: student, in: range, scope: .all)
  let indices = rows.filter { $0.exerciseID == squatID }.map(\.setIndex).sorted()
  #expect(indices == [0, 1, 2])
}

@available(iOS 17.0, macOS 14.0, *)
@MainActor
@Test func repeatLastPrefillsWeightsAndClearsRPE() async throws {
  let clock = Clock(shanghaiDate("2026-07-04T10:00:00Z"))
  let seed = [
    seededLog(
      exerciseID: squatID, loggedDate: "2026-07-01", setIndex: 0, weight: 140, reps: 5,
      rpe: 8, loggedAtISO: "2026-07-01T08:00:00Z"),
    seededLog(
      exerciseID: benchID, loggedDate: "2026-07-01", setIndex: 0, weight: 90, reps: 8,
      rpe: 7.5, loggedAtISO: "2026-07-01T08:30:00Z"),
    seededLog(
      exerciseID: squatID, loggedDate: "2026-06-20", setIndex: 0, weight: 130, reps: 5,
      rpe: 9, loggedAtISO: "2026-06-20T08:00:00Z"),
  ]
  let (viewModel, _) = makeViewModel(seed: seed, clock: clock)
  await viewModel.load()

  #expect(viewModel.lastSessionDate == "2026-07-01")
  #expect(viewModel.lastSessionDrafts.count == 2)

  viewModel.repeatLastSession()
  #expect(viewModel.drafts.count == 2)
  let squatDraft = try #require(viewModel.drafts.first { $0.exerciseID == squatID })
  #expect(squatDraft.weightKg == 140)
  #expect(squatDraft.reps == 5)
  #expect(squatDraft.rpe == nil)
  #expect(squatDraft.completed == false)
}

@available(iOS 17.0, macOS 14.0, *)
@MainActor
@Test func suggestionsRankRecentByDayAndFrequentByCount() async throws {
  let clock = Clock(shanghaiDate("2026-07-04T10:00:00Z"))
  let seed = [
    seededLog(
      exerciseID: squatID, loggedDate: "2026-06-10", setIndex: 0,
      loggedAtISO: "2026-06-10T08:00:00Z"),
    seededLog(
      exerciseID: squatID, loggedDate: "2026-06-12", setIndex: 0,
      loggedAtISO: "2026-06-12T08:00:00Z"),
    seededLog(
      exerciseID: squatID, loggedDate: "2026-06-14", setIndex: 0,
      loggedAtISO: "2026-06-14T08:00:00Z"),
    seededLog(
      exerciseID: benchID, loggedDate: "2026-07-01", setIndex: 0,
      loggedAtISO: "2026-07-01T08:00:00Z"),
  ]
  let (viewModel, _) = makeViewModel(seed: seed, clock: clock)
  await viewModel.load()

  #expect(viewModel.suggestions.recent.first == benchID)
  #expect(viewModel.suggestions.frequent.first == squatID)
}
