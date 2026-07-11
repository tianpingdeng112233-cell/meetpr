import CoreModels
import Foundation
import Observation
import RepositoryContracts

/// Mutable working copy the 2-step sheet edits before submitting.
public struct ReadinessDraft: Equatable, Sendable {
  public var sleepQuality: Int?
  public var mood: Int?
  public var stress: Int?
  /// muscleGroup → severity (1-3). Absent key = not fatigued.
  public var fatigue: [MuscleGroup: Int]

  public init(
    sleepQuality: Int? = nil,
    mood: Int? = nil,
    stress: Int? = nil,
    fatigue: [MuscleGroup: Int] = [:]
  ) {
    self.sleepQuality = sleepQuality
    self.mood = mood
    self.stress = stress
    self.fatigue = fatigue
  }

  public init(from checkin: ReadinessCheckin) {
    sleepQuality = checkin.sleepQuality
    mood = checkin.mood
    stress = checkin.stress
    fatigue = Dictionary(
      uniqueKeysWithValues: checkin.muscleFatigue.map { ($0.muscleGroup, $0.severity) })
  }

  public var stepOneComplete: Bool {
    sleepQuality != nil && mood != nil && stress != nil
  }
}

/// Per-day "skipped" marker. Historically capped the sheet's auto-present to
/// once a day; since check-in went opt-in (2026-07-11) it only feeds the
/// `skippedToday` gate state. UserDefaults-backed in production; injectable
/// for tests.
public protocol ReadinessSkipStore: Sendable {
  func isSkipped(studentId: UUID, checkinDate: String) -> Bool
  func markSkipped(studentId: UUID, checkinDate: String)
}

public struct UserDefaultsReadinessSkipStore: ReadinessSkipStore {
  public init() {}

  public func isSkipped(studentId: UUID, checkinDate: String) -> Bool {
    UserDefaults.standard.bool(forKey: Self.key(studentId, checkinDate))
  }

  public func markSkipped(studentId: UUID, checkinDate: String) {
    UserDefaults.standard.set(true, forKey: Self.key(studentId, checkinDate))
  }

  private static func key(_ studentId: UUID, _ checkinDate: String) -> String {
    "readiness.skipped.\(studentId.uuidString).\(checkinDate)"
  }
}

@Observable
@MainActor
public final class ReadinessCheckinViewModel {
  public enum Gate: Equatable, Sendable {
    case unknown
    /// Not filed today, not skipped. The toolbar heart shows the unfilled
    /// state; the sheet only opens from that manual entry point (check-in is
    /// opt-in since 2026-07-11 — no view may auto-present it).
    case needed
    /// Filed today; toolbar icon shows "done", tap re-opens prefilled.
    case done(ReadinessCheckin)
    /// Skipped today via the sheet's 跳过 button; toolbar icon allows manual entry.
    case skippedToday
  }

  public private(set) var gate: Gate = .unknown
  public private(set) var submitError: String?

  private let repo: any ReadinessRepository
  private let skipStore: any ReadinessSkipStore
  private let now: @Sendable () -> Date

  public init(
    repo: any ReadinessRepository,
    skipStore: any ReadinessSkipStore = UserDefaultsReadinessSkipStore(),
    now: @escaping @Sendable () -> Date = { Date() }
  ) {
    self.repo = repo
    self.skipStore = skipStore
    self.now = now
  }

  public var todayString: String {
    Self.dateOnly(now())
  }

  public func load(studentId: UUID) async {
    let day = todayString
    if let checkin = try? await repo.fetchCheckin(studentId: studentId, checkinDate: day) {
      gate = .done(checkin)
      return
    }
    gate = skipStore.isSkipped(studentId: studentId, checkinDate: day) ? .skippedToday : .needed
  }

  /// Returns true on success (the sheet dismisses); failure keeps the sheet
  /// up with an inline error.
  public func submit(_ draft: ReadinessDraft, studentId: UUID) async -> Bool {
    guard let sleep = draft.sleepQuality, let mood = draft.mood, let stress = draft.stress else {
      submitError = "请先完成三项状态评分"
      return false
    }
    let checkin = ReadinessCheckin(
      id: UUID(),
      studentId: studentId,
      checkinDate: todayString,
      sleepQuality: sleep,
      mood: mood,
      stress: stress,
      muscleFatigue: ReadinessCheckin.allowedMuscleGroups.compactMap { group in
        draft.fatigue[group].map { MuscleFatigue(muscleGroup: group, severity: $0) }
      },
      submittedAt: now()
    )
    do {
      try await repo.submit(checkin)
      submitError = nil
      gate = .done(checkin)
      return true
    } catch {
      submitError = "提交失败，请重试"
      return false
    }
  }

  public func skip(studentId: UUID) {
    skipStore.markSkipped(studentId: studentId, checkinDate: todayString)
    gate = .skippedToday
  }

  public func clearError() {
    submitError = nil
  }

  /// Student-local calendar day, mirroring WireFormatting.dateOnlyString —
  /// duplicated here because StudentKit shouldn't reach into Networking for
  /// a date formatter (and the local day, not UTC, is the product semantic).
  private static func dateOnly(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .iso8601)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
  }
}
