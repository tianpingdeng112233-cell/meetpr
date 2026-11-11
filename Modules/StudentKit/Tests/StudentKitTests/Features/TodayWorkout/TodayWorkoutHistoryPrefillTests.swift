import CoreModels
import Foundation
import Networking
import RepositoryContracts
import Testing

@testable import StudentKit

@MainActor
@Test(arguments: [false, true])
func trainingHistoryPrefillSwitchControlsRequestsOnOpenAndDayChange(
  historyPrefillEnabled: Bool
) async throws {
  let now = Date(timeIntervalSince1970: 1_768_262_400)
  let exercise = Exercise(
    id: UUID(), name: "Squat", exerciseType: .mainLift, isCompetitionLift: true,
    muscleGroups: [], equipment: [], createdAt: now)
  let days = (0..<2).map { index in
    StudentPlanDay(
      id: UUID(), weekNumber: 1, dayOfWeek: index + 1, sortOrder: index,
      date: now.addingTimeInterval(Double(index) * 86_400),
      exercises: [
        StudentPlanExercise(
          id: UUID(), exercise: exercise, sequenceIndex: 0,
          prescribedSets: [PrescribedSet(id: UUID(), setIndex: 0, reps: 5, rpe: 8)])
      ])
  }
  let plan = StudentPlanView(cycleID: UUID(), weekIndex: 1, startDate: now, days: days)
  let stub = HistoryPrefillAPIStub(plan: plan)
  let api = APIClient(environment: ["MEETPR_API_BASE_URL": "https://history.test"]) { request in
    try await stub.respond(to: request)
  }
  let directory = FileManager.default.temporaryDirectory.appending(path: "history-\(UUID())")
  defer { try? FileManager.default.removeItem(at: directory) }
  let repository = BackendStudentPlanRepository(
    api: api, session: HistoryPrefillSession(),
    cache: StudentPlanCache(directory: directory),
    catalogCache: ExerciseCatalogCache(directory: directory))
  let model =
    if historyPrefillEnabled {
      TodayWorkoutViewModel(
        plans: repository, logs: InMemoryStudentTrainingLogRepository(),
        historyWeightPrefillEnabled: true, now: { now })
    } else {
      TodayWorkoutViewModel(
        plans: repository, logs: InMemoryStudentTrainingLogRepository(), now: { now })
    }

  var expectedPaths: [String] = []
  for dayID in [nil, days[1].id, days[0].id] {
    await model.load(dayID: dayID, studentID: StudentDemoSeed.studentID, preloadedPlan: plan)
    #expect(model.currentDay?.id == (dayID ?? days[0].id))
    let row = try #require(model.allDaySheet.first?.rows.first)
    #expect(row.actualWeight == (historyPrefillEnabled ? 102.5 : nil))
    #expect(row.actualReps == 5)
    #expect(row.actualRPE == 8)
    if historyPrefillEnabled {
      expectedPaths.append(
        "/students/\(StudentDemoSeed.studentID)/plan-days/\(dayID ?? days[0].id)/weight-suggestions"
      )
    }
    #expect(await stub.suggestionPaths == expectedPaths)
    if !historyPrefillEnabled { #expect(await stub.suggestionPaths.isEmpty) }
  }
}

private actor HistoryPrefillAPIStub {
  let plan: StudentPlanView
  private(set) var suggestionPaths: [String] = []

  init(plan: StudentPlanView) { self.plan = plan }

  func respond(to request: URLRequest) throws -> APIResponse {
    let path = try #require(request.url?.path)
    if path.hasSuffix("/weight-suggestions") {
      suggestionPaths.append(path)
      #expect(request.httpMethod == "GET")
      let day = try #require(plan.days.first { path.contains($0.id.uuidString) })
      let suggestions = day.exercises.flatMap(\.prescribedSets).map {
        SetWeightSuggestionRecord(
          planSetID: $0.id, weightKg: 102.5, sourceSetLogID: UUID(),
          sourceLoggedDate: "2026-01-01")
      }
      return APIResponse(
        data: try MeetPRCodec.encoder.encode(["suggestions": suggestions]), statusCode: 200)
    }
    if path.hasSuffix("/plans") {
      return APIResponse(data: Data(#"{"plans":[]}"#.utf8), statusCode: 200)
    }
    #expect(path == "/exercises")
    return APIResponse(data: Data(#"{"exercises":[]}"#.utf8), statusCode: 200)
  }
}

private struct HistoryPrefillSession: SessionStateReader {
  func accessToken() async throws -> String { "test-token" }
  func currentUser() async throws -> User { throw SessionStateReaderError.missingCurrentUser }
}
