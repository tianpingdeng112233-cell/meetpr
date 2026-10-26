import CoreModels
import Foundation
import Observation
import SwiftUI

/// Shared by the gate and dashboard; persisted flags are scoped to one binding.
@Observable
@MainActor
final class BindFirstRunExperience {
  private(set) var request: BindRequest?
  private(set) var welcomeSeen = false
  private(set) var planDismissed = false
  private(set) var isTerminal = false
  private let studentID: UUID
  private let defaults: UserDefaults

  init(studentID: UUID, defaults: UserDefaults = .standard) {
    self.studentID = studentID
    self.defaults = defaults
  }

  var showsWelcome: Bool {
    request?.firstRun != nil && !isTerminal && !welcomeSeen
  }

  func update(_ request: BindRequest?) {
    self.request = request?.status == .accepted ? request : nil
    welcomeSeen = read("welcome")
    planDismissed = read("plan")
    isTerminal = read("terminal")
    if self.request?.firstRun?.hasSettledDay == true {
      write("terminal")
      isTerminal = true
      continueFromWelcome()
      dismissPlan()
    }
  }

  func continueFromWelcome() {
    write("welcome")
    welcomeSeen = true
  }

  func dismissPlan() {
    write("plan")
    planDismissed = true
  }

  private func read(_ flag: String) -> Bool {
    guard let key = key(flag) else { return false }
    return defaults.bool(forKey: key)
  }

  private func write(_ flag: String) {
    guard let key = key(flag) else { return }
    defaults.set(true, forKey: key)
  }

  private func key(_ flag: String) -> String? {
    guard let request else { return nil }
    return "meetpr.bind.first_run.\(studentID.uuidString).\(request.id.uuidString).\(flag)"
  }
}

private struct BindFirstRunKey: EnvironmentKey {
  static let defaultValue: BindFirstRunExperience? = nil
}

private struct RefreshBindFirstRunKey: EnvironmentKey {
  static let defaultValue: @MainActor @Sendable () async -> Void = {}
}

extension EnvironmentValues {
  var bindFirstRun: BindFirstRunExperience? {
    get { self[BindFirstRunKey.self] }
    set { self[BindFirstRunKey.self] = newValue }
  }

  var refreshBindFirstRun: @MainActor @Sendable () async -> Void {
    get { self[RefreshBindFirstRunKey.self] }
    set { self[RefreshBindFirstRunKey.self] = newValue }
  }
}
