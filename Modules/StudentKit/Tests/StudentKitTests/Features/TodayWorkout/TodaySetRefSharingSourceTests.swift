import ChatUI
import CoreModels
import Foundation
import Testing

@testable import StudentKit

// swiftlint:disable file_length type_body_length
@Suite("Today set-ref sharing")
struct TodaySetRefSharingSourceTests {
  @Test("every recorded row is selectable and replaces its planned candidate")
  func everyRecordedRowIsSelectableAndReplacesItsPlannedCandidate() async throws {
    let fixture = makeFixture()
    let now = fixture.now
    let source = TodaySetRefSharingSource(
      studentID: fixture.studentID,
      plans: InMemoryStudentPlanRepository(
        store: TestStudentPlanStore(seed: [fixture.studentID: fixture.plan])
      ),
      logs: InMemoryStudentTrainingLogRepository(seed: fixture.logs),
      videoManager: VideoUploadServices.demo().manager,
      calendar: fixture.calendar,
      now: { now }
    )

    let candidates = try await source.loadCandidates()
    let candidate = try #require(
      candidates.first(where: { $0.id == fixture.completedLogID })
    )

    #expect(candidates.count == 3)
    #expect(candidates.allSatisfy { $0.source.source == .logged })
    #expect(candidate.source.exerciseName == "低杠位深蹲")
    #expect(candidate.source.setNumber == 1)
    #expect(candidate.source.setTotal == 3)
    #expect(candidate.source.weightKg == "100")
    #expect(candidate.source.reps == 5)
    #expect(candidate.source.repsMax == nil)
    #expect(candidate.source.rpe == "8")
    #expect(candidate.source.dayDate == "2026-07-28")
    #expect(candidate.source.setLogId == fixture.completedLogID)
    #expect(candidate.source.planSetId == nil)
    #expect(candidate.video.map { _ in false } ?? true)
  }

  @MainActor
  @Test("an assumed log row is selectable and a planned workout shows the entry")
  func assumedLogAndPlannedWorkoutEnableSharing() async throws {
    let fixture = makeFixture()
    let assumedLogs = fixture.logs.filter(\.assumed)
    let source = makeSource(fixture: fixture, logs: assumedLogs)
    let day = try #require(fixture.plan.days.first)
    let drafts = TodayWorkoutViewModel.makeDrafts(
      for: day,
      existingLogs: assumedLogs
    )

    let candidates = try await source.loadCandidates()
    #expect(candidates.contains { $0.source.source == .logged })
    #expect(candidates.contains { $0.source.source == .planned })
    #expect(
      SetRefEntryVisibility.shouldShow(
        drafts: drafts,
        isEditable: true,
        hasActiveCoach: true,
        hasSharingContext: true
      )
    )
  }

  @Test("an uploaded video resolves to its backend attachment id")
  func uploadedVideoResolvesToRemoteAttachmentID() async throws {
    let fixture = makeFixture()
    let now = fixture.now
    let remoteVideoID = UUID()
    let repository = InMemoryVideoAttachmentRepository()
    let manager = VideoUploadManager(
      service: LoopbackVideoUploadService(),
      exporter: MockVideoExporter(),
      repository: repository
    )
    try await repository.save(
      VideoAttachment(
        id: UUID(),
        setLogID: fixture.completedLogID,
        studentID: fixture.studentID,
        remoteAttachmentID: remoteVideoID,
        status: .uploaded,
        contentType: "video/mp4",
        durationSeconds: 10,
        sizeBytes: 1,
        recordedAt: now,
        uploadedAt: now
      )
    )
    let source = TodaySetRefSharingSource(
      studentID: fixture.studentID,
      plans: InMemoryStudentPlanRepository(
        store: TestStudentPlanStore(seed: [fixture.studentID: fixture.plan])
      ),
      logs: InMemoryStudentTrainingLogRepository(seed: fixture.logs),
      videoManager: manager,
      calendar: fixture.calendar,
      now: { now }
    )

    let candidate = try #require(
      try await source.loadCandidates().first {
        $0.id == fixture.completedLogID
      }
    )
    let video = try #require(candidate.video)
    let selection = try #require(await video.selection())

    #expect(video.state == .ready)
    guard case .ready(let resolvedID) = selection else {
      Issue.record("expected a ready set-ref video")
      return
    }
    #expect(resolvedID == remoteVideoID)
  }

  @Test("an in-flight video maps the manager ready event")
  // swiftlint:disable:next function_body_length
  func uploadingVideoMapsReadyEvent() async throws {
    let fixture = makeFixture()
    let now = fixture.now
    let localAttachmentID = UUID()
    let remoteVideoID = UUID()
    let repository = InMemoryVideoAttachmentRepository()
    let manager = VideoUploadManager(
      service: LoopbackVideoUploadService(),
      exporter: MockVideoExporter(),
      repository: repository
    )
    let uploading = VideoAttachment(
      id: localAttachmentID,
      setLogID: fixture.completedLogID,
      studentID: fixture.studentID,
      remoteAttachmentID: remoteVideoID,
      status: .uploading,
      contentType: "video/mp4",
      durationSeconds: 10,
      sizeBytes: 1,
      recordedAt: now
    )
    try await repository.save(uploading)
    let source = TodaySetRefSharingSource(
      studentID: fixture.studentID,
      plans: InMemoryStudentPlanRepository(
        store: TestStudentPlanStore(seed: [fixture.studentID: fixture.plan])
      ),
      logs: InMemoryStudentTrainingLogRepository(seed: fixture.logs),
      videoManager: manager,
      calendar: fixture.calendar,
      now: { now }
    )
    let candidate = try #require(
      try await source.loadCandidates().first {
        $0.id == fixture.completedLogID
      }
    )
    let video = try #require(candidate.video)
    let selection = try #require(await video.selection())
    guard case .uploading(let resolvedLocalID, let events) = selection else {
      Issue.record("expected an uploading set-ref video")
      return
    }

    var uploaded = uploading
    uploaded.status = .uploaded
    uploaded.uploadedAt = now
    try await repository.save(uploaded)
    await manager.broadcast(.updated(uploaded, progress: 1))
    let event = await events.first { _ in true }

    #expect(video.state == .uploading)
    #expect(resolvedLocalID == localAttachmentID)
    #expect(
      event
        == .ready(
          localAttachmentID: localAttachmentID,
          videoID: remoteVideoID
        )
    )
  }

  @Test("entry requires an available set, an active coach, and sharing wiring")
  func entryVisibilityRequiresEveryGate() {
    #expect(
      SetRefEntryVisibility.shouldShow(
        isEditable: true,
        hasAvailableSet: true,
        hasActiveCoach: true,
        hasSharingContext: true
      )
    )
    #expect(
      !SetRefEntryVisibility.shouldShow(
        isEditable: true,
        hasAvailableSet: true,
        hasActiveCoach: false,
        hasSharingContext: true
      )
    )
    #expect(
      !SetRefEntryVisibility.shouldShow(
        isEditable: false,
        hasAvailableSet: true,
        hasActiveCoach: true,
        hasSharingContext: true
      )
    )
    #expect(
      !SetRefEntryVisibility.shouldShow(
        isEditable: true,
        hasAvailableSet: false,
        hasActiveCoach: true,
        hasSharingContext: true
      )
    )
    #expect(
      !SetRefEntryVisibility.shouldShow(
        isEditable: true,
        hasAvailableSet: true,
        hasActiveCoach: true,
        hasSharingContext: false
      )
    )
  }

  @Test("most recently completed set is the first picker candidate")
  func mostRecentlyCompletedSetIsFirst() async throws {
    let fixture = makeFixture()
    let planExerciseID = try #require(fixture.plan.days.first?.exercises.first?.id)
    let mostRecentLogID = UUID()
    var logs = fixture.logs
    logs.append(
      StudentSetLog(
        id: mostRecentLogID,
        studentID: fixture.studentID,
        planExerciseID: planExerciseID,
        setIndex: 1,
        loggedAt: fixture.now.addingTimeInterval(60),
        weightKg: 102.5,
        reps: 5,
        rpe: 8.5,
        completed: true
      )
    )
    let now = fixture.now
    let source = TodaySetRefSharingSource(
      studentID: fixture.studentID,
      plans: InMemoryStudentPlanRepository(
        store: TestStudentPlanStore(seed: [fixture.studentID: fixture.plan])
      ),
      logs: InMemoryStudentTrainingLogRepository(seed: logs),
      videoManager: VideoUploadServices.demo().manager,
      calendar: fixture.calendar,
      now: { now }
    )

    let candidates = try await source.loadCandidates()

    #expect(candidates.first?.id == mostRecentLogID)
  }

  @Test("failed recorded rows remain shareable")
  func failedRecordedRowsRemainShareable() async throws {
    let fixture = makeFixture()
    let planExerciseID = try #require(fixture.plan.days.first?.exercises.first?.id)
    let failedID = UUID()
    let failed = StudentSetLog(
      id: failedID,
      studentID: fixture.studentID,
      planExerciseID: planExerciseID,
      setIndex: 0,
      loggedAt: fixture.now,
      weightKg: 100,
      reps: 0,
      rpe: 10,
      completed: false,
      failed: true
    )

    let candidates = try await makeSource(
      fixture: fixture,
      logs: [failed]
    ).loadCandidates()

    let candidate = try #require(candidates.first(where: { $0.id == failedID }))
    #expect(candidate.source.source == .logged)
    #expect(candidate.source.reps == 0)
  }

  @Test("planned candidates map intensity and ranges without rounding invalid values")
  // swiftlint:disable:next function_body_length
  func plannedCandidatesMapIntensityAndRejectInvalidValues() async throws {
    let fixture = makeFixture()
    let day = try #require(fixture.plan.days.first)
    let original = try #require(day.exercises.first)
    let weightSetID = UUID()
    let rpeSetID = UUID()
    let exercise = StudentPlanExercise(
      id: original.id,
      exercise: original.exercise,
      sequenceIndex: original.sequenceIndex,
      prescribedSets: [
        PrescribedSet(
          id: weightSetID,
          setIndex: 0,
          weightKg: 175,
          reps: 3,
          repsMax: 5
        ),
        PrescribedSet(
          id: rpeSetID,
          setIndex: 1,
          reps: 5,
          rpe: 8
        ),
        PrescribedSet(
          id: UUID(),
          setIndex: 2,
          reps: 5,
          rpe: Decimal(string: "7.25")
        ),
        PrescribedSet(
          id: UUID(),
          setIndex: 3,
          weightKg: 10_000,
          reps: 5
        ),
      ]
    )
    let plan = StudentPlanView(
      cycleID: fixture.plan.cycleID,
      weekIndex: fixture.plan.weekIndex,
      startDate: fixture.plan.startDate,
      days: [
        StudentPlanDay(id: day.id, date: day.date, exercises: [exercise])
      ]
    )
    let source = TodaySetRefSharingSource(
      studentID: fixture.studentID,
      plans: InMemoryStudentPlanRepository(
        store: TestStudentPlanStore(seed: [fixture.studentID: plan])
      ),
      logs: InMemoryStudentTrainingLogRepository(),
      videoManager: VideoUploadServices.demo().manager,
      calendar: fixture.calendar,
      now: { fixture.now }
    )

    let candidates = try await source.loadCandidates()

    #expect(candidates.map(\.id) == [weightSetID, rpeSetID])
    #expect(candidates.allSatisfy { $0.source.source == .planned })
    #expect(candidates[0].source.setNumber == 1)
    #expect(candidates[0].source.setTotal == 4)
    #expect(candidates[0].source.weightKg == "175")
    #expect(candidates[0].source.reps == 3)
    #expect(candidates[0].source.repsMax == 5)
    #expect(candidates[0].source.rpe == nil)
    #expect(candidates[0].source.planSetId == weightSetID)
    #expect(candidates[1].source.weightKg == nil)
    #expect(candidates[1].source.rpe == "8")
  }

  @Test("equal completion timestamps prefer larger sequence then set index")
  // swiftlint:disable:next function_body_length
  func equalTimestampOrderingIsDeterministic() async throws {
    let fixture = makeFixture()
    let firstDay = try #require(fixture.plan.days.first)
    let firstExercise = try #require(firstDay.exercises.first)
    let laterExercise = StudentPlanExercise(
      id: UUID(),
      exercise: Exercise(
        id: UUID(),
        name: "卧推",
        exerciseType: .mainLift,
        mainLiftFamily: .bench,
        isCompetitionLift: true,
        muscleGroups: [.chest],
        equipment: [.barbell],
        movementPattern: [.horizontalPush],
        createdAt: fixture.now
      ),
      sequenceIndex: firstExercise.sequenceIndex + 1,
      prescribedSets: [
        PrescribedSet(id: UUID(), setIndex: 0, weightKg: 80, reps: 5, rpe: 8)
      ]
    )
    let plan = StudentPlanView(
      cycleID: fixture.plan.cycleID,
      weekIndex: fixture.plan.weekIndex,
      startDate: fixture.plan.startDate,
      days: [
        StudentPlanDay(
          id: firstDay.id,
          date: firstDay.date,
          exercises: [firstExercise, laterExercise]
        )
      ]
    )
    let higherSetID = UUID()
    let higherSequenceID = UUID()
    let logs = [
      fixture.logs[0],
      StudentSetLog(
        id: higherSetID,
        studentID: fixture.studentID,
        planExerciseID: firstExercise.id,
        setIndex: 1,
        loggedAt: fixture.now,
        weightKg: 100,
        reps: 5,
        rpe: 8,
        completed: true
      ),
      StudentSetLog(
        id: higherSequenceID,
        studentID: fixture.studentID,
        planExerciseID: laterExercise.id,
        setIndex: 0,
        loggedAt: fixture.now,
        weightKg: 80,
        reps: 5,
        rpe: 8,
        completed: true
      ),
    ]
    let source = TodaySetRefSharingSource(
      studentID: fixture.studentID,
      plans: InMemoryStudentPlanRepository(
        store: TestStudentPlanStore(seed: [fixture.studentID: plan])
      ),
      logs: InMemoryStudentTrainingLogRepository(seed: logs),
      videoManager: VideoUploadServices.demo().manager,
      calendar: fixture.calendar,
      now: { fixture.now }
    )

    let candidates = try await source.loadCandidates()

    #expect(
      Array(candidates.prefix(3).map(\.id))
        == [higherSequenceID, higherSetID, fixture.completedLogID]
    )
  }

  @Test("gym-day candidates include 00:00-03:59 and exclude adjacent days")
  // swiftlint:disable:next function_body_length
  func gymDayRangeMatchesTrainingScreenAtEarlyMorning() async throws {
    let fixture = makeFixture()
    let planExerciseID = try #require(fixture.plan.days.first?.exercises.first?.id)
    let earlyMorningID = UUID()
    let now = try date(
      year: 2026,
      month: 7,
      day: 29,
      hour: 0,
      minute: 30,
      calendar: fixture.calendar
    )
    let logs = [
      fixture.logs[0],
      completedLog(
        id: earlyMorningID,
        fixture: fixture,
        planExerciseID: planExerciseID,
        setIndex: 1,
        loggedAt: try date(
          year: 2026,
          month: 7,
          day: 29,
          hour: 3,
          minute: 59,
          calendar: fixture.calendar
        )
      ),
      completedLog(
        fixture: fixture,
        planExerciseID: planExerciseID,
        setIndex: 2,
        loggedAt: try date(
          year: 2026,
          month: 7,
          day: 29,
          hour: 4,
          minute: 0,
          calendar: fixture.calendar
        )
      ),
      completedLog(
        fixture: fixture,
        planExerciseID: planExerciseID,
        setIndex: 2,
        loggedAt: try date(
          year: 2026,
          month: 7,
          day: 28,
          hour: 3,
          minute: 59,
          calendar: fixture.calendar
        )
      ),
    ]
    let source = makeSource(fixture: fixture, logs: logs, now: now)

    let candidates = try await source.loadCandidates()

    let loggedIDs =
      candidates
      .filter { $0.source.source == .logged }
      .map(\.id)
    #expect(Set(loggedIDs) == [fixture.completedLogID, earlyMorningID])
  }
}

private struct TodaySetRefFixture {
  let studentID: UUID
  let completedLogID: UUID
  let now: Date
  let calendar: Calendar
  let plan: StudentPlanView
  let logs: [StudentSetLog]
}

private func makeSource(
  fixture: TodaySetRefFixture,
  logs: [StudentSetLog],
  now: Date? = nil
) -> TodaySetRefSharingSource {
  TodaySetRefSharingSource(
    studentID: fixture.studentID,
    plans: InMemoryStudentPlanRepository(
      store: TestStudentPlanStore(seed: [fixture.studentID: fixture.plan])
    ),
    logs: InMemoryStudentTrainingLogRepository(seed: logs),
    videoManager: VideoUploadServices.demo().manager,
    calendar: fixture.calendar,
    now: { now ?? fixture.now }
  )
}

private func completedLog(
  id: UUID = UUID(),
  fixture: TodaySetRefFixture,
  planExerciseID: UUID,
  setIndex: Int,
  loggedAt: Date
) -> StudentSetLog {
  StudentSetLog(
    id: id,
    studentID: fixture.studentID,
    planExerciseID: planExerciseID,
    setIndex: setIndex,
    loggedAt: loggedAt,
    weightKg: 100,
    reps: 5,
    rpe: 8,
    completed: true
  )
}

// swiftlint:disable:next function_parameter_count
private func date(
  year: Int,
  month: Int,
  day: Int,
  hour: Int,
  minute: Int,
  calendar: Calendar
) throws -> Date {
  try #require(
    calendar.date(
      from: DateComponents(
        year: year,
        month: month,
        day: day,
        hour: hour,
        minute: minute
      )
    )
  )
}

// swiftlint:disable:next function_body_length
private func makeFixture() -> TodaySetRefFixture {
  var calendar = Calendar(identifier: .gregorian)
  calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3_600) ?? calendar.timeZone
  let now =
    calendar.date(
      from: DateComponents(year: 2026, month: 7, day: 28, hour: 12)
    ) ?? Date(timeIntervalSince1970: 1_775_000_000)
  let studentID = UUID()
  let planExerciseID = UUID()
  let completedLogID = UUID()
  let exercise = Exercise(
    id: UUID(),
    name: "低杠位深蹲",
    exerciseType: .mainLift,
    mainLiftFamily: .squat,
    isCompetitionLift: true,
    muscleGroups: [.quad],
    equipment: [.barbell],
    movementPattern: [.squat],
    createdAt: now
  )
  let planExercise = StudentPlanExercise(
    id: planExerciseID,
    exercise: exercise,
    sequenceIndex: 0,
    prescribedSets: [
      PrescribedSet(id: UUID(), setIndex: 0, weightKg: 100, reps: 5, rpe: 8),
      PrescribedSet(id: UUID(), setIndex: 1, weightKg: 100, reps: 5, rpe: 8),
      PrescribedSet(id: UUID(), setIndex: 2, weightKg: 100, reps: 5, rpe: 8),
    ]
  )
  let day = StudentPlanDay(id: UUID(), date: now, exercises: [planExercise])
  let plan = StudentPlanView(
    cycleID: UUID(),
    weekIndex: 1,
    startDate: now,
    days: [day]
  )
  let logs = [
    StudentSetLog(
      id: completedLogID,
      studentID: studentID,
      planExerciseID: planExerciseID,
      setIndex: 0,
      loggedAt: now,
      weightKg: 100,
      reps: 5,
      rpe: 8,
      completed: true
    ),
    StudentSetLog(
      id: UUID(),
      studentID: studentID,
      planExerciseID: planExerciseID,
      setIndex: 1,
      loggedAt: now,
      weightKg: 100,
      reps: 5,
      rpe: 8,
      completed: false
    ),
    StudentSetLog(
      id: UUID(),
      studentID: studentID,
      planExerciseID: planExerciseID,
      setIndex: 2,
      loggedAt: now,
      weightKg: 100,
      reps: 5,
      rpe: 8,
      completed: true,
      assumed: true
    ),
  ]
  return TodaySetRefFixture(
    studentID: studentID,
    completedLogID: completedLogID,
    now: now,
    calendar: calendar,
    plan: plan,
    logs: logs
  )
}
// swiftlint:enable file_length type_body_length
