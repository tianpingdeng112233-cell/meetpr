import ChatUI
import CoreModels
import DesignSystem
import Foundation
import RepositoryContracts

struct TodaySetRefSharingSource: Sendable {
  private let studentID: UUID
  private let plans: any StudentPlanRepository
  private let logs: any StudentTrainingLogRepository
  private let videoManager: VideoUploadManager
  private let calendar: Calendar
  private let now: @Sendable () -> Date

  init(
    studentID: UUID,
    plans: any StudentPlanRepository,
    logs: any StudentTrainingLogRepository,
    videoManager: VideoUploadManager,
    calendar: Calendar = .current,
    now: @escaping @Sendable () -> Date = { Date() }
  ) {
    self.studentID = studentID
    self.plans = plans
    self.logs = logs
    self.videoManager = videoManager
    self.calendar = calendar
    self.now = now
  }

  func sharingContext() -> SetRefSharingContext {
    SetRefSharingContext {
      try await loadCandidates()
    }
  }

  // swiftlint:disable:next function_body_length
  func loadCandidates() async throws -> [SetRefShareCandidate] {
    let today = WorkoutDatePolicy.gymDayToday(now: now())
    let plan = try await plans.fetchCurrentPlan(studentID: studentID)
    let day: StudentPlanDay?
    if let plannedDay = plan?.days.first(where: {
      PlanCalendarDayIdentity.matches(
        planDate: $0.date,
        selectedDate: today,
        selectedCalendar: calendar
      )
    }) {
      day = plannedDay
    } else {
      day = try await plans.fetchDay(studentID: studentID, date: today)
    }
    guard let day else {
      return []
    }

    let dayRange = WorkoutDatePolicy.dayRange(containing: day.date, calendar: calendar)
    let dayLogs = try await logs.fetchLogs(
      studentID: studentID,
      in: dayRange
    )
    let exerciseByID = Dictionary(
      uniqueKeysWithValues: day.exercises.map { ($0.id, $0) }
    )
    let videoBySetLogID = await latestVideosBySetLogID()

    let loggedCandidates: [SetRefShareCandidate] =
      dayLogs
      .filter {
        SetRefRecordedSetEligibility.isEligible(loggedSetID: $0.id)
          && exerciseByID[$0.planExerciseID] != nil
      }
      .sorted(by: recentCompletionOrder(exerciseByID: exerciseByID))
      .compactMap { log -> SetRefShareCandidate? in
        guard let exercise = exerciseByID[log.planExerciseID] else { return nil }
        let setNumber = SetIndexDisplay.number(forZeroBasedIndex: log.setIndex)
        let plannedTotal = exercise.prescribedSets.count
        let setTotal = plannedTotal >= setNumber ? plannedTotal : nil
        let source = SetRefSourceSnapshot(
          source: .logged,
          exerciseName: exercise.exercise.name,
          setNumber: setNumber,
          setTotal: setTotal,
          weightKg: Self.decimalSource(log.weightKg),
          reps: log.reps,
          repsMax: nil,
          rpe: log.rpe.map(Self.decimalSource),
          dayDate: Self.dayDate(day.date, calendar: calendar),
          setLogId: log.id,
          planSetId: nil
        )
        return SetRefShareCandidate(
          id: log.id,
          source: source,
          video: videoBySetLogID[log.id].map(makeShareVideo)
        )
      }

    let loggedPlanSetIDs = Set(
      dayLogs.compactMap { log in
        exerciseByID[log.planExerciseID]?.prescribedSets
          .first(where: { $0.setIndex == log.setIndex })?
          .id
      }
    )
    let plannedCandidates: [SetRefShareCandidate] =
      day.exercises
      .sorted { lhs, rhs in
        lhs.sequenceIndex < rhs.sequenceIndex
      }
      .flatMap { exercise -> [SetRefShareCandidate] in
        exercise.prescribedSets
          .sorted { $0.setIndex < $1.setIndex }
          .compactMap { set -> SetRefShareCandidate? in
            guard !loggedPlanSetIDs.contains(set.id) else { return nil }
            return plannedCandidate(
              set,
              exercise: exercise,
              dayDate: Self.dayDate(day.date, calendar: calendar)
            )
          }
      }

    return loggedCandidates + plannedCandidates
  }

  private func plannedCandidate(
    _ set: PrescribedSet,
    exercise: StudentPlanExercise,
    dayDate: String
  ) -> SetRefShareCandidate? {
    let source = SetRefSourceSnapshot(
      source: .planned,
      exerciseName: exercise.exercise.name,
      setNumber: SetIndexDisplay.number(forZeroBasedIndex: set.setIndex),
      setTotal: exercise.prescribedSets.count,
      weightKg: set.weightKg.map(Self.decimalSource),
      reps: set.reps,
      repsMax: set.repsMax,
      rpe: set.rpe.map(Self.decimalSource),
      dayDate: dayDate,
      setLogId: nil,
      planSetId: set.id
    )
    guard (try? SetRefV1.normalizingSource(source)) != nil else {
      return nil
    }
    return SetRefShareCandidate(id: set.id, source: source)
  }
}

extension TodaySetRefSharingSource {
  private func latestVideosBySetLogID() async -> [UUID: VideoAttachment] {
    var result: [UUID: VideoAttachment] = [:]
    for attachment in await videoManager.attachments(studentID: studentID)
    where result[attachment.setLogID] == nil {
      result[attachment.setLogID] = attachment
    }
    return result
  }

  private func makeShareVideo(_ attachment: VideoAttachment) -> SetRefShareVideo {
    SetRefShareVideo(
      state: Self.shareVideoState(attachment.status),
      resolve: { [videoManager, studentID, attachmentID = attachment.id] in
        await Self.resolveVideoSelection(
          manager: videoManager,
          studentID: studentID,
          attachmentID: attachmentID
        )
      }
    )
  }

  private func recentCompletionOrder(
    exerciseByID: [UUID: StudentPlanExercise]
  ) -> (StudentSetLog, StudentSetLog) -> Bool {
    { lhs, rhs in
      // BackendStudentTrainingLogRepository replaces the client timestamp with
      // the canonical `logged_at` returned by recordSet; cached/fetched logs
      // therefore compare the backend clock. In-memory tests preserve the
      // supplied fixture clock.
      if lhs.loggedAt != rhs.loggedAt {
        return lhs.loggedAt > rhs.loggedAt
      }
      let lhsSequence = exerciseByID[lhs.planExerciseID]?.sequenceIndex ?? .min
      let rhsSequence = exerciseByID[rhs.planExerciseID]?.sequenceIndex ?? .min
      if lhsSequence != rhsSequence {
        return lhsSequence > rhsSequence
      }
      return lhs.setIndex > rhs.setIndex
    }
  }

  private static func resolveVideoSelection(
    manager: VideoUploadManager,
    studentID: UUID,
    attachmentID: UUID
  ) async -> SetRefVideoSelection? {
    // Subscribe before reading current state so a completion racing this
    // resolver is buffered rather than falling into the read→subscribe gap.
    let managerEvents = await manager.events()
    guard
      let attachment = await manager.attachments(studentID: studentID)
        .first(where: { $0.id == attachmentID })
    else {
      return nil
    }

    switch attachment.status {
    case .uploaded:
      guard let remoteID = attachment.remoteAttachmentID else { return nil }
      return .ready(videoID: remoteID)
    case .pending, .uploading:
      return .uploading(
        localAttachmentID: attachment.id,
        events: setRefEvents(
          managerEvents: managerEvents,
          attachmentID: attachment.id
        )
      )
    case .failed:
      return nil
    }
  }

  private static func setRefEvents(
    managerEvents: AsyncStream<VideoUploadEvent>,
    attachmentID: UUID
  ) -> AsyncStream<SetRefVideoUploadEvent> {
    let (stream, continuation) = AsyncStream.makeStream(
      of: SetRefVideoUploadEvent.self,
      bufferingPolicy: .bufferingNewest(8)
    )
    let task = Task {
      for await event in managerEvents {
        switch event {
        case .updated(let attachment, _)
        where attachment.id == attachmentID && attachment.status == .uploaded:
          if let remoteID = attachment.remoteAttachmentID {
            continuation.yield(
              .ready(localAttachmentID: attachmentID, videoID: remoteID)
            )
            continuation.finish()
            return
          }
        case .updated(let attachment, _)
        where attachment.id == attachmentID && attachment.status == .failed:
          continuation.yield(.failed(localAttachmentID: attachmentID))
          continuation.finish()
          return
        case .removed(_, let removedID) where removedID == attachmentID:
          continuation.yield(.removed(localAttachmentID: attachmentID))
          continuation.finish()
          return
        default:
          continue
        }
      }
      continuation.finish()
    }
    continuation.onTermination = { _ in
      task.cancel()
    }
    return stream
  }

  private static func shareVideoState(_ status: VideoAttachment.Status)
    -> SetRefShareVideo.State
  {
    switch status {
    case .pending, .uploading:
      .uploading
    case .uploaded:
      .ready
    case .failed:
      .failed
    }
  }

  private static func decimalSource(_ value: Decimal) -> String {
    NSDecimalNumber(decimal: value).stringValue
  }

  private static func dayDate(_ date: Date, calendar: Calendar) -> String {
    let components = calendar.dateComponents([.year, .month, .day], from: date)
    let year = components.year ?? 0
    let month = components.month ?? 0
    let day = components.day ?? 0
    return "\(padded(year, width: 4))-\(padded(month, width: 2))-\(padded(day, width: 2))"
  }

  fileprivate static func padded(_ value: Int, width: Int) -> String {
    let raw = String(value)
    return String(repeating: "0", count: max(0, width - raw.count)) + raw
  }
}

enum SetRefRecordedSetEligibility {
  static func isEligible(loggedSetID: UUID?) -> Bool {
    loggedSetID != nil
  }
}
