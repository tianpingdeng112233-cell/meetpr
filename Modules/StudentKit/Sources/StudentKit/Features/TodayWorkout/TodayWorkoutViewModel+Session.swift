import Foundation
import RepositoryContracts

struct LocalSessionOverride: Equatable, Sendable {
  let gymDay: String?
  let session: TrainingSession
}

@available(iOS 17.0, macOS 14.0, *)
extension TodayWorkoutViewModel {
  public func startSession() async {
    sessionStartGeneration += 1
    let startedAt = now()
    let localSession = TrainingSession(
      status: .inProgress,
      startedAt: startedAt,
      lastSetAt: startedAt,
      completedAt: nil,
      durationSeconds: 0
    )
    localSessionOverride = LocalSessionOverride(gymDay: currentGymDay, session: localSession)
    sessionPage = .inProgress(localSession)
    scheduleSessionStartCoordination()
    await sessionStartTask?.value
  }

  func applyFetchedSession(
    _ fetchedSnapshot: TrainingSessionSnapshot?,
    isToday: Bool,
    issuedStartGeneration: Int
  ) {
    guard isToday else {
      sessionPage = Self.resolveSessionPage(for: fetchedSnapshot?.session)
      return
    }

    // A GET issued before the most recent local start is stale IN ITS
    // ENTIRETY: none of it (null included) may write back — regardless of
    // whether the optimistic override still exists or a POST already replaced
    // it with server truth. Re-render whatever state is current and drop the
    // snapshot on the floor.
    guard issuedStartGeneration == sessionStartGeneration else {
      if let localSessionOverride {
        sessionPage = Self.resolveSessionPage(for: localSessionOverride.session)
      }
      return
    }

    guard let localSessionOverride else {
      currentGymDay = fetchedSnapshot?.gymDay
      sessionPage = Self.resolveSessionPage(for: fetchedSnapshot?.session)
      return
    }

    guard let fetchedSnapshot else {
      sessionPage = Self.resolveSessionPage(for: localSessionOverride.session)
      if localSessionOverride.session.status == .inProgress {
        scheduleSessionStartCoordination()
      }
      return
    }

    guard let fetchedSession = fetchedSnapshot.session else {
      currentGymDay = fetchedSnapshot.gymDay
      guard
        let fetchedGymDay = fetchedSnapshot.gymDay,
        let overrideGymDay = localSessionOverride.gymDay,
        fetchedGymDay == overrideGymDay
      else {
        self.localSessionOverride = nil
        sessionStartTask?.cancel()
        sessionStartTask = nil
        sessionPage = .overview
        return
      }

      sessionPage = Self.resolveSessionPage(for: localSessionOverride.session)
      if localSessionOverride.session.status == .inProgress {
        scheduleSessionStartCoordination()
      }
      return
    }

    applyAuthoritativeSession(fetchedSession, gymDay: fetchedSnapshot.gymDay)
  }

  // Reached only past the top-of-function generation gate (GET) or from a
  // POST response — both are server truth by construction.
  private func applyAuthoritativeSession(_ session: TrainingSession, gymDay: String?) {
    currentGymDay = gymDay
    localSessionOverride = nil
    sessionPage = Self.resolveSessionPage(for: session)
  }

  private func scheduleSessionStartCoordination() {
    guard sessionStartTask == nil else { return }
    sessionStartTask = Task { [weak self] in
      await self?.coordinateSessionStart()
    }
  }

  private func coordinateSessionStart() async {
    defer { sessionStartTask = nil }
    for _ in 0..<2 {
      guard !Task.isCancelled else { return }
      do {
        let startedSnapshot = try await sessions.startSession()
        guard !Task.isCancelled else { return }
        guard let startedSession = startedSnapshot.session else { return }
        // While browsing a history date, a late POST result must not repaint
        // the read-only view: the session is safely persisted server-side and
        // the next today-load GET will surface it authoritatively.
        guard viewingToday else { return }
        applyAuthoritativeSession(startedSession, gymDay: startedSnapshot.gymDay)
        return
      } catch {
        guard !Task.isCancelled else { return }
        // The local transition remains authoritative. A null GET on a later
        // reload schedules another silent coordination attempt.
      }
    }
  }

  public func sessionElapsedSeconds(at date: Date) -> Int? {
    TrainingSessionTimer.elapsedSeconds(for: sessionPage, now: date)
  }

  static func resolveSessionPage(
    for session: TrainingSession?
  ) -> TodayWorkoutSessionPage {
    guard let session else { return .overview }
    switch session.status {
    case .inProgress:
      return .inProgress(session)
    case .completed, .partial:
      return .completed(session)
    }
  }

  func completeSessionLocally(at completedAt: Date) async {
    guard case .inProgress(let session) = sessionPage else { return }
    let duration = max(0, Int(completedAt.timeIntervalSince(session.startedAt)))
    let completed = TrainingSession(
      status: .completed,
      startedAt: session.startedAt,
      lastSetAt: completedAt,
      completedAt: completedAt,
      durationSeconds: duration
    )
    localSessionOverride = LocalSessionOverride(gymDay: currentGymDay, session: completed)
    sessionPage = .completed(completed)
    if let currentStudentID {
      recentCompletedDurationStore.record(
        durationSeconds: duration,
        studentID: currentStudentID
      )
    }
    await sessions.markCompleted(date: session.startedAt, duration: duration)
  }
}
