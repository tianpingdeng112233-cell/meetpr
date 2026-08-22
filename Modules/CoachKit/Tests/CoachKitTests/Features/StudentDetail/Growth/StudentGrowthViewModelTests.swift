import CoreModels
import Foundation
import Networking
import Testing
import ViewInspector

@testable import CoachKit

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test
// swiftlint:disable:next function_body_length
func growthMapsBackendSeriesAndHeadlineWithoutDecimalPrecisionLoss() async throws {
  let json = #"""
    {
      "e1rm": {
        "squat": { "value": "180.123456789012345678", "computed_at": "2026-08-20T10:00:00Z" },
        "bench": { "value": "120.50", "computed_at": "2026-08-19T10:00:00Z" },
        "deadlift": null
      },
      "e1rm_series": {
        "squat": {
          "points": [
            { "date": "2026-07-01", "value": "170.000000000000000001" },
            { "date": "2026-08-20", "value": "180.123456789012345678" }
          ],
          "trend": "down"
        },
        "bench": {
          "points": [{ "date": "2026-08-19", "value": "120.50" }],
          "trend": "new"
        },
        "deadlift": { "points": [], "trend": "future_value" }
      },
      "one_rm": { "squat": "180.00", "bench": "120.00", "deadlift": null }
    }
    """#
  let api = APIClient(environment: ["MEETPR_API_BASE_URL": "https://api.test"]) { request in
    #expect(
      request.url?.path()
        == "/coach/students/\(CoachStudentFeatureFixtures.studentID.uuidString)/exercise-stats"
    )
    #expect(request.value(forHTTPHeaderField: "authorization") == "Bearer coach-token")
    return APIResponse(data: Data(json.utf8), statusCode: 200)
  }
  let viewModel = StudentGrowthViewModel(
    exerciseStats: BackendCoachExerciseStatsRepository(
      api: api,
      session: GrowthTestSession()
    )
  )

  await viewModel.load(
    studentID: CoachStudentFeatureFixtures.studentID,
    now: try #require(utcDate("2026-08-21"))
  )

  let squatPoints = viewModel.points(for: .squat)
  let firstDate = try #require(utcDate("2026-07-01"))
  let secondDate = try #require(utcDate("2026-08-20"))
  let firstValue = try #require(decimal("170.000000000000000001"))
  let secondValue = try #require(decimal("180.123456789012345678"))
  let benchValue = try #require(decimal("120.50"))
  #expect(viewModel.state == .loaded)
  #expect(squatPoints.map(\.date) == [firstDate, secondDate])
  #expect(squatPoints.map(\.e1RMKg) == [firstValue, secondValue])
  #expect(viewModel.headlineE1RM(for: .squat) == secondValue)
  #expect(viewModel.headlineE1RM(for: .bench) == benchValue)
  #expect(viewModel.trend(for: .squat) == .downward)
  #expect(viewModel.trend(for: .bench) == .new)
  #expect(viewModel.trend(for: .deadlift) == .unknown("future_value"))
  #expect(viewModel.oneRMByFamily == [.squat: 180, .bench: 120])
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func growthFiltersBackendPointsBySelectedFamilyAndWindow() async throws {
  let now = try #require(utcDate("2026-08-21"))
  let recent = try #require(utcDate("2026-08-19"))
  let old = try #require(utcDate("2026-07-01"))
  let snapshot = CoachExerciseStatsSnapshot(
    seriesByFamily: [
      .squat: .init(
        points: [
          .init(date: old, valueKg: 170),
          .init(date: recent, valueKg: 180),
        ],
        trend: .upward
      )
    ]
  )
  let viewModel = StudentGrowthViewModel(
    exerciseStats: InMemoryCoachExerciseStatsRepository(
      snapshots: [CoachStudentFeatureFixtures.studentID: snapshot]
    )
  )

  await viewModel.loadIfNeeded(studentID: CoachStudentFeatureFixtures.studentID, now: now)

  #expect(viewModel.visiblePoints.map(\.date) == [recent])
  viewModel.selectedWindow = .threeMonths
  #expect(viewModel.visiblePoints.map(\.date) == [old, recent])
  viewModel.selectedFamily = .bench
  #expect(viewModel.visiblePoints.isEmpty)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func growthMissingSeriesLoadsAsExistingEmptyState() async throws {
  let response = CoachExerciseStatsResponseDTO(
    e1RM: .init(squat: .init(value: "180.00")),
    oneRM: .init(squat: "175.00")
  )
  let snapshot = try BackendCoachExerciseStatsRepository.snapshot(from: response)
  let viewModel = StudentGrowthViewModel(
    exerciseStats: InMemoryCoachExerciseStatsRepository(
      snapshots: [CoachStudentFeatureFixtures.studentID: snapshot]
    )
  )

  await viewModel.load(
    studentID: CoachStudentFeatureFixtures.studentID,
    now: CoachStudentFeatureFixtures.startDate
  )

  #expect(viewModel.state == .loaded)
  #expect(LiftFamily.allCases.allSatisfy { viewModel.points(for: $0).isEmpty })
  let inspected = try StudentGrowthView(
    studentID: CoachStudentFeatureFixtures.studentID,
    now: CoachStudentFeatureFixtures.startDate,
    viewModel: viewModel
  ).inspect()
  _ = try inspected.find(text: CoachGrowthStrings.empty)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func growthFailureRendersRetryAndRetrySuccessShowsData() async throws {
  let successful = CoachExerciseStatsSnapshot(
    e1RMByFamily: [.squat: .init(valueKg: 180)],
    seriesByFamily: [
      .squat: .init(
        points: [.init(date: CoachStudentFeatureFixtures.startDate, valueKg: 180)],
        trend: .upward
      )
    ]
  )
  let repository = SequencedCoachExerciseStatsRepository(results: [
    .failure(CoachFeatureTestError()),
    .success(successful),
  ])
  let viewModel = StudentGrowthViewModel(exerciseStats: repository)
  let view = StudentGrowthView(
    studentID: CoachStudentFeatureFixtures.studentID,
    now: CoachStudentFeatureFixtures.startDate,
    viewModel: viewModel
  )

  await viewModel.load(
    studentID: CoachStudentFeatureFixtures.studentID,
    now: CoachStudentFeatureFixtures.startDate
  )

  #expect(viewModel.state == .failed(CoachGrowthStrings.loadFailed))
  let inspected = try view.inspect()
  _ = try inspected.find(text: CoachGrowthStrings.loadFailed)
  try inspected.find(button: CoachDetailStrings.retry).tap()

  for _ in 0..<200 where viewModel.state != .loaded {
    try await Task.sleep(for: .milliseconds(5))
  }
  #expect(viewModel.state == .loaded)
  #expect(viewModel.points(for: .squat).map(\.e1RMKg) == [180])
  #expect(await repository.requestCount() == 2)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func growthLoadingRendersProgressWithoutFlashingEmptyState() async throws {
  let repository = SuspendedCoachExerciseStatsRepository()
  let viewModel = StudentGrowthViewModel(exerciseStats: repository)
  let loadTask = Task {
    await viewModel.load(
      studentID: CoachStudentFeatureFixtures.studentID,
      now: CoachStudentFeatureFixtures.startDate
    )
  }

  for _ in 0..<200 where !(await repository.hasStarted()) {
    await Task.yield()
  }
  #expect(viewModel.state == .loading)
  let inspected = try StudentGrowthView(
    studentID: CoachStudentFeatureFixtures.studentID,
    now: CoachStudentFeatureFixtures.startDate,
    viewModel: viewModel
  ).inspect()
  _ = try inspected.find(ViewType.ProgressView.self)
  #expect(throws: (any Error).self) {
    _ = try inspected.find(text: CoachGrowthStrings.empty)
  }

  await repository.finish(with: CoachExerciseStatsSnapshot())
  await loadTask.value
}

private struct GrowthTestSession: SessionStateReader {
  func accessToken() async throws -> String {
    "coach-token"
  }

  func currentUser() async throws -> User {
    User(
      id: CoachStudentFeatureFixtures.coachID,
      phone: "+8613800000001",
      unitSystem: .metric,
      role: .coach,
      createdAt: CoachStudentFeatureFixtures.startDate,
      updatedAt: CoachStudentFeatureFixtures.startDate
    )
  }
}

private actor SequencedCoachExerciseStatsRepository: CoachExerciseStatsProviding {
  private var results: [Result<CoachExerciseStatsSnapshot, CoachFeatureTestError>]
  private var requests = 0

  init(results: [Result<CoachExerciseStatsSnapshot, CoachFeatureTestError>]) {
    self.results = results
  }

  func fetchExerciseStats(studentID: UUID) async throws -> CoachExerciseStatsSnapshot {
    requests += 1
    guard !results.isEmpty else { return CoachExerciseStatsSnapshot() }
    return try results.removeFirst().get()
  }

  func requestCount() -> Int {
    requests
  }
}

private actor SuspendedCoachExerciseStatsRepository: CoachExerciseStatsProviding {
  private var started = false
  private var continuation: CheckedContinuation<CoachExerciseStatsSnapshot, Never>?

  func fetchExerciseStats(studentID: UUID) async throws -> CoachExerciseStatsSnapshot {
    started = true
    return await withCheckedContinuation { continuation in
      self.continuation = continuation
    }
  }

  func hasStarted() -> Bool {
    started
  }

  func finish(with snapshot: CoachExerciseStatsSnapshot) {
    continuation?.resume(returning: snapshot)
    continuation = nil
  }
}

private func decimal(_ rawValue: String) -> Decimal? {
  Decimal(string: rawValue, locale: Locale(identifier: "en_US_POSIX"))
}

private func utcDate(_ rawValue: String) -> Date? {
  let components = rawValue.split(separator: "-")
  guard components.count == 3,
    let year = Int(components[0]),
    let month = Int(components[1]),
    let day = Int(components[2]),
    let timeZone = TimeZone(secondsFromGMT: 0)
  else { return nil }
  var calendar = Calendar(identifier: .iso8601)
  calendar.timeZone = timeZone
  return calendar.date(from: DateComponents(year: year, month: month, day: day))
}
