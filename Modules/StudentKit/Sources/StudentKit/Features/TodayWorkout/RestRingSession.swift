import Foundation
import Observation

@MainActor @Observable
final class RestRingSession {
  enum Presentation: String, Identifiable {
    case settings, countdown
    var id: String { rawValue }
  }
  private(set) var model = RestRingModel()
  var settings = RestRingSettings()
  var presentation: Presentation?
  private(set) var clock: Date
  private var foreground = true
  private var pendingBackgroundCompletion = false
  private var configuredStudent: UUID?
  private var persist: (RestRingSettings) -> Void = { _ in }
  private let controller: any RestTimerActivityControlling
  private let now: () -> Date
  private let feedback: (RestRingModel.Alert) -> Void
  private var ticker: Task<Void, Never>?

  init(
    controller: any RestTimerActivityControlling,
    now: @escaping () -> Date = Date.init,
    feedback: @escaping (RestRingModel.Alert) -> Void = { _ in }
  ) {
    self.controller = controller
    self.now = now
    self.clock = now()
    self.feedback = feedback
  }

  func configure(
    student: UUID, settings: RestRingSettings, persist: @escaping (RestRingSettings) -> Void
  ) {
    guard configuredStudent != student else { return }
    if configuredStudent != nil { end() }
    configuredStudent = student
    self.settings = settings
    self.persist = persist
    applyAlertSettings()
  }

  func updatePresentationContext(isTrainable: Bool, hasOtherPresentation: Bool) {
    guard settings.needsFirstSettings else { return }
    guard isTrainable, !hasOtherPresentation else {
      // Yield an unfinished automatic setup without marking it as seen.
      if presentation == .settings { presentation = nil }
      return
    }
    if presentation == nil { presentation = .settings }
  }

  func tap(seconds: Int, exercise: String) {
    settings.useRing()
    persist(settings)
    tick()
    switch model.phase {
    case .idle: start(seconds: seconds, exercise: exercise)
    case .running: presentation = .countdown
    case .done: end()
    }
  }

  func openSettings() {
    settings.useRing()
    persist(settings)
    presentation = .settings
  }

  func dismiss() {
    if presentation == .settings {
      settings.finishSetup()
      persist(settings)
      applyAlertSettings()
    }
    presentation = nil
  }

  func applyAlertSettings() {
    controller.setAlerts(sound: settings.sound, vibration: settings.vibration)
  }

  func start(seconds: Int, exercise: String) {
    ticker?.cancel()
    clock = now()
    model.start(seconds: seconds, exercise: exercise, at: clock)
    applyAlertSettings()
    if let endsAt = model.endsAt {
      controller.start(endsAt: endsAt, totalSeconds: model.totalSeconds)
    }
    tick()
    ticker = Task { @MainActor [weak self] in
      while !Task.isCancelled {
        do { try await Task.sleep(for: .milliseconds(100)) } catch { return }
        guard let self, self.model.phase != .idle else { return }
        self.tick()
      }
    }
  }

  func adjust(by delta: Int) {
    guard model.phase == .running else { return }
    clock = now()
    feedback(
      model.adjust(
        by: delta, at: clock, foreground: foreground,
        vibration: settings.vibration, sound: settings.sound))
    if model.phase == .running, let endsAt = model.endsAt {
      controller.update(endsAt: endsAt, totalSeconds: model.totalSeconds)
    } else {
      controller.end()
      if presentation == .countdown { presentation = nil }
    }
  }

  func end() {
    ticker?.cancel()
    pendingBackgroundCompletion = false
    model.end()
    controller.end()
    if presentation == .countdown { presentation = nil }
  }

  func completeToday() {
    end()
    presentation = nil
  }

  func setForeground(_ active: Bool) {
    foreground = active
    // Consume any background expiry before enabling foreground effects.
    tick(allowFeedback: false)
    controller.setForeground(active)
    if active && pendingBackgroundCompletion {
      pendingBackgroundCompletion = false
      controller.end()
    }
  }

  func tick(allowFeedback: Bool = true) {
    clock = now()
    let before = model.phase
    let alert = model.tick(
      at: clock, foreground: foreground && allowFeedback,
      vibration: settings.vibration, sound: settings.sound)
    feedback(alert)
    if before == .running, model.phase != .running {
      if foreground { controller.end() } else { pendingBackgroundCompletion = true }
      if presentation == .countdown { presentation = nil }
    }
  }
}
