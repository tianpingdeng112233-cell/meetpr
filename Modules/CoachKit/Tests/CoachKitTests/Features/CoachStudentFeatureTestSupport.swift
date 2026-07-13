import CoreModels
import Foundation
import RepositoryContracts

@testable import CoachKit

enum CoachStudentFeatureFixtures {
  static let coachID = UUID(uuidString: "02900000-0000-0000-0000-000000000001")!
  static let studentID = UUID(uuidString: "02900000-0000-0000-0000-000000000101")!
  static let secondStudentID = UUID(uuidString: "02900000-0000-0000-0000-000000000102")!
  static let exerciseID = UUID(uuidString: "02900000-0000-0000-0000-000000000201")!
  static let planExerciseID = UUID(uuidString: "02900000-0000-0000-0000-000000000301")!
  static let setID = UUID(uuidString: "02900000-0000-0000-0000-000000000401")!
  static let startDate = Date(timeIntervalSince1970: 1_769_817_600)  // 2026-01-30

  static func summary(
    id: UUID = studentID,
    name: String = "测试学员",
    status: CoachStudentStatus = .active
  ) -> CoachStudentSummary {
    CoachStudentSummary(id: id, displayName: name, status: status)
  }

  static func plan(
    startDate: Date = startDate,
    trainingOffsets: Set<Int> = [1],
    totalShiftDays: Int = 0
  ) -> StudentPlanView {
    StudentPlanView(
      cycleID: UUID(uuidString: "02900000-0000-0000-0000-000000000501")!,
      weekIndex: 1,
      startDate: startDate,
      totalShiftDays: totalShiftDays,
      days: (0..<7).map { offset in
        let date = startDate.addingTimeInterval(Double(offset) * 86_400)
        if trainingOffsets.contains(offset) {
          return StudentPlanDay(
            id: UUID(uuidString: String(format: "02900000-0000-0000-0000-%012d", 600 + offset))!,
            date: date,
            exercises: [exercise()]
          )
        }
        return StudentPlanDay(
          id: UUID(uuidString: String(format: "02900000-0000-0000-0000-%012d", 700 + offset))!,
          date: date,
          exercises: []
        )
      }
    )
  }

  static func exercise() -> StudentPlanExercise {
    StudentPlanExercise(
      id: planExerciseID,
      exercise: Exercise(
        id: exerciseID,
        name: "深蹲",
        exerciseType: .mainLift,
        mainLiftFamily: .squat,
        isCompetitionLift: true,
        muscleGroups: [.quad, .glute],
        equipment: [.barbell],
        movementPattern: [.squat],
        createdAt: startDate
      ),
      sequenceIndex: 0,
      prescribedSets: [
        PrescribedSet(
          id: setID,
          setIndex: 0,
          weightKg: 140,
          reps: 5,
          rpe: 8
        )
      ]
    )
  }

  static func log(
    studentID: UUID = studentID,
    loggedAt: Date = startDate.addingTimeInterval(86_400 + 3_600)
  ) -> StudentSetLog {
    StudentSetLog(
      id: UUID(),
      studentID: studentID,
      planExerciseID: planExerciseID,
      setIndex: 0,
      loggedAt: loggedAt,
      weightKg: 142.5,
      reps: 5,
      rpe: 8.5,
      completed: true
    )
  }

  static func video(
    id: UUID = UUID(),
    createdAt: Date = startDate.addingTimeInterval(86_400 + 2 * 3_600),
    loggedAt: Date? = startDate.addingTimeInterval(86_400 + 3_600)
  ) -> StudentVideo {
    StudentVideo(
      id: id,
      setLogID: setID,
      planExerciseID: planExerciseID,
      contentType: "video/mp4",
      sizeBytes: 15_728_640,
      filename: "setlog-test.mp4",
      createdAt: createdAt,
      loggedAt: loggedAt
    )
  }

  static func readinessCheckin(
    studentID: UUID = studentID,
    checkinDate: String,
    muscleFatigue: [MuscleFatigue] = [
      MuscleFatigue(muscleGroup: .quad, severity: 3),
      MuscleFatigue(muscleGroup: .core, severity: 1),
    ]
  ) -> ReadinessCheckin {
    ReadinessCheckin(
      id: UUID(uuidString: "02900000-0000-0000-0000-000000000901")!,
      studentId: studentID,
      checkinDate: checkinDate,
      sleepQuality: 4,
      mood: 3,
      stress: 2,
      muscleFatigue: muscleFatigue,
      submittedAt: startDate
    )
  }

  static func feedback(
    studentID: UUID = studentID,
    postedAt: Date = startDate.addingTimeInterval(2 * 86_400)
  ) -> CoachFeedback {
    CoachFeedback(
      id: UUID(),
      coachID: coachID,
      studentID: studentID,
      dayDate: startDate.addingTimeInterval(86_400),
      planExerciseID: planExerciseID,
      text: "保持这个节奏，下一组不要急。",
      postedAt: postedAt,
      readAt: nil
    )
  }
}

struct CoachFeatureTestError: Error, Equatable {}

actor StubCoachPlanRepository: PlanRepository {
  var students: [CoachStudentSummary]
  var error: Error?

  init(students: [CoachStudentSummary], error: Error? = nil) {
    self.students = students
    self.error = error
  }

  func fetchStudents() async throws -> [CoachStudentSummary] {
    if let error { throw error }
    return students
  }

  func fetchMainLiftCatalog() async throws -> [Exercise] {
    []
  }

  func fetchAccessoryExercises(filters: AccessoryFilters) async throws -> [Exercise] {
    []
  }

  func publishPlan(
    plan: TrainingPlan,
    days: [PlanDay],
    exercises: [PlanExercise],
    sets: [PlanSet]
  ) async throws {}
}

actor StubStudentPlanRepository: StudentPlanRepository {
  var plans: [UUID: StudentPlanView]

  init(plans: [UUID: StudentPlanView]) {
    self.plans = plans
  }

  func fetchCurrentPlan(studentID: UUID) async throws -> StudentPlanView? {
    plans[studentID]
  }

  func fetchDay(studentID: UUID, date: Date) async throws -> StudentPlanDay? {
    plans[studentID]?.days.first { CoachFeatureCalendar.isSameDay($0.date, date) }
  }

  func fetchCycleDays(studentID: UUID) async throws -> [StudentPlanDay] {
    plans[studentID]?.days ?? []
  }
}

actor StubTrainingLogRepository: StudentTrainingLogRepository {
  var logs: [StudentSetLog]

  init(logs: [StudentSetLog]) {
    self.logs = logs
  }

  @discardableResult
  func recordSet(_ log: StudentSetLog) async throws -> StudentSetLog {
    logs.append(log)
    return log
  }

  func fetchLogs(studentID: UUID, in dateRange: ClosedRange<Date>) async throws -> [StudentSetLog] {
    logs.filter { $0.studentID == studentID && dateRange.contains($0.loggedAt) }
  }

  func fetchLogsForExercise(
    studentID: UUID,
    planExerciseID: UUID
  ) async throws -> [StudentSetLog] {
    logs.filter { $0.studentID == studentID && $0.planExerciseID == planExerciseID }
  }
}

actor StubFeedbackRepository: StudentFeedbackRepository {
  private struct PostedFeedbackRequest {
    let studentID: UUID
    let dayDate: Date?
    let planExerciseID: UUID?
    let text: String
  }

  var feedback: [CoachFeedback]
  var postError: Error?
  private var postedRequests: [PostedFeedbackRequest] = []

  init(feedback: [CoachFeedback] = [], postError: Error? = nil) {
    self.feedback = feedback
    self.postError = postError
  }

  func fetchInbox(studentID: UUID) async throws -> [CoachFeedback] {
    feedback.filter { $0.studentID == studentID }.sorted { $0.postedAt > $1.postedAt }
  }

  func postFeedback(
    studentID: UUID,
    dayDate: Date?,
    planExerciseID: UUID?,
    text: String
  ) async throws -> CoachFeedback {
    if let postError { throw postError }
    postedRequests.append(
      PostedFeedbackRequest(
        studentID: studentID,
        dayDate: dayDate,
        planExerciseID: planExerciseID,
        text: text
      )
    )
    // Reflect the requested scope (not a canned fixture) so consumers that
    // refetch — e.g. the video-inbox de-queue — actually exercise the scope
    // the caller posted (Codex review nit, 2026-06-23).
    let item = CoachFeedback(
      id: UUID(),
      coachID: CoachStudentFeatureFixtures.coachID,
      studentID: studentID,
      dayDate: dayDate,
      planExerciseID: planExerciseID,
      text: text,
      postedAt: CoachStudentFeatureFixtures.startDate.addingTimeInterval(4 * 86_400),
      readAt: nil
    )
    feedback.append(item)
    return item
  }

  func markRead(feedbackID: UUID) async throws {}

  func postedTexts() -> [String] {
    postedRequests.map(\.text)
  }
}

actor StubCoachStudentVideoRepository: CoachStudentVideoRepository {
  var videos: [StudentVideo]
  var playbackURLs: [UUID: URL]
  var fetchError: Error?
  var playbackError: Error?

  init(
    videos: [StudentVideo] = [],
    playbackURLs: [UUID: URL] = [:],
    fetchError: Error? = nil,
    playbackError: Error? = nil
  ) {
    self.videos = videos
    self.playbackURLs = playbackURLs
    self.fetchError = fetchError
    self.playbackError = playbackError
  }

  func fetchVideos(studentID: UUID) async throws -> [StudentVideo] {
    if let fetchError { throw fetchError }
    return videos.sorted { $0.createdAt > $1.createdAt }
  }

  func playbackURL(videoID: UUID) async throws -> URL {
    if let playbackError { throw playbackError }
    guard let url = playbackURLs[videoID] else { throw CoachFeatureTestError() }
    return url
  }
}

actor StubReadinessRepository: ReadinessRepository {
  var checkinsByDate: [String: ReadinessCheckin]
  var fetchError: Error?

  init(checkins: [ReadinessCheckin] = [], fetchError: Error? = nil) {
    self.checkinsByDate = Dictionary(
      uniqueKeysWithValues: checkins.map { ($0.checkinDate, $0) }
    )
    self.fetchError = fetchError
  }

  func submit(_ checkin: ReadinessCheckin) async throws {
    checkinsByDate[checkin.checkinDate] = checkin
  }

  func fetchCheckin(studentId: UUID, checkinDate: String) async throws -> ReadinessCheckin? {
    if let fetchError { throw fetchError }
    let checkin = checkinsByDate[checkinDate]
    return checkin?.studentId == studentId ? checkin : nil
  }
}
