import CoreModels
import Foundation
import RepositoryContracts

/// Opt-in fixtures. Only demo dependency assembly and demo seed factories use this flag.
public enum ProgressDemoScenario: String, Sendable {
  case missingLift = "missing-lift"
  case squatOnly = "squat-only"
  case zero
  case single
  case allRead = "all-read"
  case noFeedback = "no-feedback"
  case multiweek
  case fourDigit = "four-digit"
  case forming
  case sparse
  case noRPE = "no-rpe"
  case loading
  case loadFailure = "load-failure"

  public static var launchValue: Self? {
    let arguments = ProcessInfo.processInfo.arguments
    guard let index = arguments.firstIndex(of: "-spec087-progress"),
      arguments.indices.contains(index + 1)
    else { return nil }
    return Self(rawValue: arguments[index + 1])
  }

  func logs(studentID: UUID) -> [StudentSetLog] {
    guard self != .zero else { return [] }
    let offsets = self == .single || self == .forming ? [-1] : [-21, -14, -7, -1]
    return offsets.map { offset in
      StudentSetLog(
        id: UUID(), studentID: studentID, planExerciseID: UUID(), exerciseID: UUID(),
        setIndex: 0, loggedAt: date(offset), weightKg: 100, reps: 5,
        rpe: self == .noRPE ? nil : 8, completed: true)
    }
  }

  func points(studentID: UUID) -> [E1RMHistoryPoint] {
    guard self != .zero else { return [] }
    let families: [LiftFamily] =
      self == .missingLift ? [.squat, .bench] : [.squat, .bench, .deadlift]
    let offsets = self == .forming ? [-1] : [-21, -14, -7]
    var points = families.flatMap { family in
      offsets.enumerated().map { index, offset in
        let base: Double = family == .squat ? 150 : family == .bench ? 100 : 200
        let increments: [Double] =
          self == .sparse
          ? [0, 0, 0]
          : family == .squat ? [0, 5, 2] : family == .bench ? [0, 2, 1] : [0, 5, 2]
        return point(
          studentID: studentID, family: family, value: base + increments[index], offset: offset)
      }
    }
    if self == .squatOnly || self == .fourDigit {
      points.append(point(studentID: studentID, family: .squat, value: 160, offset: -1))
    }
    return points
  }

  func feedback(_ items: [CoachFeedback]) -> [CoachFeedback] {
    if self == .noFeedback { return [] }
    guard self == .allRead else { return items }
    return items.map {
      CoachFeedback(
        id: $0.id, coachID: $0.coachID, studentID: $0.studentID,
        dayDate: $0.dayDate, planExerciseID: $0.planExerciseID, videoID: $0.videoID,
        video: $0.video, text: $0.text, postedAt: $0.postedAt, readAt: $0.postedAt)
    }
  }

  private func point(
    studentID: UUID, family: LiftFamily, value: Double, offset: Int
  ) -> E1RMHistoryPoint {
    let scaled = value * (self == .fourDigit ? 3 : 1)
    let exerciseID =
      StudentDemoSeed.makePlanView().days.flatMap(\.exercises)
      .first { $0.exercise.mainLiftFamily == family }?.exercise.id ?? UUID()
    return E1RMHistoryPoint(
      id: UUID(), studentId: studentID, exerciseId: exerciseID, family: family,
      setLogId: UUID(), computedAt: date(offset), e1RMKg: scaled,
      sourceWeightKg: scaled, sourceReps: 1, sourceRPE: 10)
  }

  private func date(_ offset: Int) -> Date {
    let calendar = Calendar.current
    let today = calendar.startOfDay(for: Date())
    return calendar.date(byAdding: .day, value: offset, to: today) ?? today
  }

  public static func logRepository(
    wrapping repository: any StudentTrainingLogRepository
  ) -> any StudentTrainingLogRepository {
    guard let scenario = launchValue, scenario == .loading || scenario == .loadFailure else {
      return repository
    }
    return ProgressDemoLogRepository(base: repository, scenario: scenario)
  }
}

private struct ProgressDemoLogRepository: StudentTrainingLogRepository {
  let base: any StudentTrainingLogRepository
  let scenario: ProgressDemoScenario

  func recordSet(_ log: StudentSetLog) async throws -> StudentSetLog {
    try await base.recordSet(log)
  }

  func fetchLogs(studentID: UUID, in dateRange: ClosedRange<Date>) async throws -> [StudentSetLog] {
    if scenario == .loadFailure { throw URLError(.notConnectedToInternet) }
    try await Task.sleep(for: .seconds(8))
    return try await base.fetchLogs(studentID: studentID, in: dateRange)
  }

  func fetchLogsForExercise(studentID: UUID, planExerciseID: UUID) async throws -> [StudentSetLog] {
    try await base.fetchLogsForExercise(studentID: studentID, planExerciseID: planExerciseID)
  }
}
