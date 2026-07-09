import CoreModels
import Foundation
import Observation
import RepositoryContracts

protocol DashboardPlanSeenStoring: Sendable {
  func hasSeen(studentID: UUID, signature: DashboardPlanSignature) -> Bool
  func markSeen(studentID: UUID, signature: DashboardPlanSignature)
}

struct DashboardPlanSignature: Equatable, Hashable, Sendable {
  let rawValue: String

  init(plan: StudentPlanView) {
    rawValue = [
      plan.cycleID.uuidString,
      String(plan.weekIndex),
      String(Int(plan.startDate.timeIntervalSince1970)),
    ].joined(separator: ".")
  }
}

struct DashboardPlanNotice: Equatable, Sendable {
  let signature: DashboardPlanSignature
  let weekIndex: Int
}

final class UserDefaultsDashboardPlanSeenStore: DashboardPlanSeenStoring, @unchecked Sendable {
  private let defaults: UserDefaults

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  func hasSeen(studentID: UUID, signature: DashboardPlanSignature) -> Bool {
    defaults.bool(forKey: key(studentID: studentID, signature: signature))
  }

  func markSeen(studentID: UUID, signature: DashboardPlanSignature) {
    defaults.set(true, forKey: key(studentID: studentID, signature: signature))
  }

  private func key(studentID: UUID, signature: DashboardPlanSignature) -> String {
    "meetpr.dashboard.plan_seen.\(studentID.uuidString).\(signature.rawValue)"
  }
}

final class InMemoryDashboardPlanSeenStore: DashboardPlanSeenStoring, @unchecked Sendable {
  private var seen: Set<String>
  private let lock = NSLock()

  init(seed: Set<String> = []) {
    seen = seed
  }

  func hasSeen(studentID: UUID, signature: DashboardPlanSignature) -> Bool {
    lock.withLock { seen.contains(key(studentID: studentID, signature: signature)) }
  }

  func markSeen(studentID: UUID, signature: DashboardPlanSignature) {
    lock.withLock {
      _ = seen.insert(key(studentID: studentID, signature: signature))
    }
  }

  private func key(studentID: UUID, signature: DashboardPlanSignature) -> String {
    "\(studentID.uuidString).\(signature.rawValue)"
  }
}

@Observable
@MainActor
final class DashboardNotificationsViewModel {
  enum State: Equatable, Sendable {
    case idle
    case loading
    case loaded(DashboardPlanNotice?)
    case error(String)
  }

  private(set) var state: State = .idle

  @ObservationIgnored private let plans: any StudentPlanRepository
  @ObservationIgnored private let seenStore: any DashboardPlanSeenStoring
  @ObservationIgnored private var currentStudentID: UUID?

  init(
    plans: any StudentPlanRepository,
    seenStore: any DashboardPlanSeenStoring = UserDefaultsDashboardPlanSeenStore()
  ) {
    self.plans = plans
    self.seenStore = seenStore
  }

  var planNotice: DashboardPlanNotice? {
    guard case .loaded(let notice) = state else {
      return nil
    }
    return notice
  }

  func hasUnread(feedbackUnreadCount: Int, evaluationUnreadCount: Int) -> Bool {
    planNotice != nil || feedbackUnreadCount > 0 || evaluationUnreadCount > 0
  }

  func load(studentID: UUID) async {
    currentStudentID = studentID
    state = .loading
    do {
      guard let plan = try await plans.fetchCurrentPlan(studentID: studentID) else {
        state = .loaded(nil)
        return
      }
      let signature = DashboardPlanSignature(plan: plan)
      let notice =
        seenStore.hasSeen(studentID: studentID, signature: signature)
        ? nil
        : DashboardPlanNotice(signature: signature, weekIndex: plan.weekIndex)
      state = .loaded(notice)
    } catch {
      if error.isTaskCancellation {
        state = .idle
        return
      }
      state = .error(error.localizedDescription)
    }
  }

  func markCurrentPlanSeen() {
    guard let currentStudentID, let notice = planNotice else {
      return
    }
    seenStore.markSeen(studentID: currentStudentID, signature: notice.signature)
    state = .loaded(nil)
  }
}
