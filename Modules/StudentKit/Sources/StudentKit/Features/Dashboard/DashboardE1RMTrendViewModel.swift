import CoreModels
import Foundation
import Observation
import RepositoryContracts

struct DashboardE1RMTrendPresentation: Equatable, Sendable {
  let rows: [DashboardE1RMTrendRow]
  let headline: DashboardE1RMHeadline?

  var hasHistory: Bool {
    rows.contains { !$0.points.isEmpty }
  }
}

struct DashboardE1RMTrendRow: Equatable, Identifiable, Sendable {
  let family: LiftFamily
  let points: [E1RMHistoryPoint]

  var id: LiftFamily { family }

  var latestPoint: E1RMHistoryPoint? {
    points.max { $0.computedAt < $1.computedAt }
  }
}

struct DashboardE1RMHeadline: Equatable, Sendable {
  enum Kind: Equatable, Sendable {
    case latestPR
    case best
  }

  let kind: Kind
  let family: LiftFamily
  let valueKg: Double

  var label: String {
    switch kind {
    case .latestPR: "最新 PR"
    case .best: "最佳"
    }
  }
}

@Observable
@MainActor
final class DashboardE1RMTrendViewModel {
  enum State: Equatable, Sendable {
    case idle
    case loading
    case loaded(DashboardE1RMTrendPresentation)
    case error(String)
  }

  private(set) var state: State = .idle

  @ObservationIgnored private let plans: any StudentPlanRepository
  @ObservationIgnored private let e1rm: any E1RMRepository
  @ObservationIgnored private let onboarding: (any OnboardingProfileReading)?

  init(
    plans: any StudentPlanRepository,
    e1rm: any E1RMRepository,
    onboarding: (any OnboardingProfileReading)? = nil
  ) {
    self.plans = plans
    self.e1rm = e1rm
    self.onboarding = onboarding
  }

  func load(studentID: UUID) async {
    state = .loading
    do {
      let plan = try await plans.fetchCurrentPlan(studentID: studentID)
      let profile = try await onboarding?.fetchProfile(studentId: studentID)
      let idsByFamily = MainLiftExerciseFamilyResolver.exerciseIDsByFamily(
        in: plan,
        onboarding: profile
      )
      let histories = try await fetchHistories(studentID: studentID, idsByFamily: idsByFamily)
      let rows = Self.rows(from: histories, idsByFamily: idsByFamily)
      let prs = try await e1rm.unacknowledgedPRs(studentId: studentID)
      state = .loaded(
        DashboardE1RMTrendPresentation(
          rows: rows,
          headline: Self.headline(prs: prs, rows: rows, idsByFamily: idsByFamily)
        )
      )
    } catch {
      if error.isTaskCancellation {
        state = .idle
        return
      }
      state = .error(error.localizedDescription)
    }
  }

  private func fetchHistories(
    studentID: UUID,
    idsByFamily: [LiftFamily: Set<UUID>]
  ) async throws -> [UUID: [E1RMHistoryPoint]] {
    let ids = Array(idsByFamily.values.flatMap { $0 })
    guard !ids.isEmpty else {
      return [:]
    }
    return try await e1rm.fetchHistory(studentId: studentID, exerciseIds: ids)
  }

  private static func rows(
    from histories: [UUID: [E1RMHistoryPoint]],
    idsByFamily: [LiftFamily: Set<UUID>]
  ) -> [DashboardE1RMTrendRow] {
    MainLiftExerciseFamilyResolver.dashboardFamilies.map { family in
      let rawPoints = (idsByFamily[family] ?? [])
        .flatMap { histories[$0] ?? [] }
      return DashboardE1RMTrendRow(
        family: family,
        points: E1RMSeries.smoothedHistory(points: rawPoints, family: family)
      )
    }
  }

  private static func headline(
    prs: [PRBreakthroughEvent],
    rows: [DashboardE1RMTrendRow],
    idsByFamily: [LiftFamily: Set<UUID>]
  ) -> DashboardE1RMHeadline? {
    if let latestPRHeadline = latestPR(prs, idsByFamily: idsByFamily) {
      return latestPRHeadline
    }
    return bestCurrentE1RM(rows)
  }

  /// The most recent PR whose exercise still resolves to a dashboard main-lift
  /// family. Scans newest-first so an unresolvable newest PR (an accessory, or
  /// an exercise dropped from the current plan) does not hide an older but
  /// resolvable squat/bench/deadlift PR.
  private static func latestPR(
    _ prs: [PRBreakthroughEvent],
    idsByFamily: [LiftFamily: Set<UUID>]
  ) -> DashboardE1RMHeadline? {
    for event in prs.sorted(by: { $0.occurredAt > $1.occurredAt }) {
      guard
        let family = MainLiftExerciseFamilyResolver.family(
          for: event.exerciseId,
          in: idsByFamily
        )
      else {
        continue
      }
      return DashboardE1RMHeadline(
        kind: .latestPR,
        family: family,
        valueKg: event.breakthroughE1RMKg
      )
    }
    return nil
  }

  private static func bestCurrentE1RM(
    _ rows: [DashboardE1RMTrendRow]
  ) -> DashboardE1RMHeadline? {
    rows.compactMap { row -> DashboardE1RMHeadline? in
      guard let latest = row.latestPoint else {
        return nil
      }
      return DashboardE1RMHeadline(kind: .best, family: row.family, valueKg: latest.e1RMKg)
    }
    .max { $0.valueKg < $1.valueKg }
  }
}
