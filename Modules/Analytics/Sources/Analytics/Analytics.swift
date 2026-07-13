import Foundation

public final class Analytics: Sendable {
  public static let shared = Analytics()

  private let makeCore: @Sendable () -> AnalyticsCore
  private let runtime = AnalyticsRuntimeState()

  init(makeCore: @escaping @Sendable () -> AnalyticsCore = { AnalyticsCore() }) {
    self.makeCore = makeCore
  }

  public func prepare(mode: AnalyticsMode) {
    runtime.setMode(mode)
  }

  public func configure(
    baseURL: URL,
    transport: @escaping EventTransport,
    accessTokenProvider: @escaping @Sendable () async -> String?,
    mode: AnalyticsMode = .live,
    privacyNoticeConfirmed: Bool = false,
    appVersion: String? = nil,
    build: String? = nil
  ) {
    runtime.setMode(mode)
    guard case .live = mode else {
      runtime.removeCore()
      return
    }

    // Constructing AnalyticsCore creates the installation/session stores. Keep
    // that lazy so a runtime-disabled Demo never creates anon_id or queue files.
    let core = makeCore()
    let info = Bundle.main.infoDictionary
    let resolvedVersion =
      appVersion ?? info?["CFBundleShortVersionString"] as? String ?? "unknown"
    let resolvedBuild = build ?? info?["CFBundleVersion"] as? String ?? "unknown"
    let crashDirectory = URL.documentsDirectory.appending(path: "analytics/crash")
    let task = Task {
      await core.configure(
        AnalyticsConfiguration(
          baseURL: baseURL,
          transport: transport,
          accessTokenProvider: accessTokenProvider,
          mode: mode,
          privacyNoticeConfirmed: privacyNoticeConfirmed,
          appVersion: resolvedVersion,
          build: resolvedBuild,
          crashDirectory: crashDirectory))
    }
    runtime.setCore(core, configurationTask: task)
  }

  public func track(_ name: AnalyticsEvent, props: [String: AnalyticsValue] = [:]) {
    guard let configured = runtime.configuredCore else { return }
    Task {
      await configured.configurationTask.value
      await configured.core.track(name, props: props)
    }
  }

  public func screen(_ screen: AnalyticsScreen) {
    track(.screenView, props: ["screen": .enumCase(screen)])
  }

  public func flow(
    _ flow: AnalyticsFlow,
    _ step: AnalyticsFlowStep,
    props: [String: AnalyticsValue] = [:]
  ) {
    guard step == .cancel else { return }
    var resolved = props
    resolved["flow"] = .enumCase(flow)
    if resolved["from_screen"] != nil {
      track(.flowCancel, props: resolved)
    }
  }

  public func submitFrictionText(
    eventID: UUID,
    flow: AnalyticsFlow,
    fromScreen: AnalyticsScreen,
    trigger: FrictionTrigger,
    text: String
  ) {
    guard let configured = runtime.configuredCore else { return }
    Task {
      await configured.configurationTask.value
      await configured.core.submitFrictionText(
        eventID: eventID,
        flow: flow,
        fromScreen: fromScreen,
        trigger: trigger,
        text: text
      )
    }
  }

  public func confirmPrivacyNotice() {
    guard let configured = runtime.configuredCore else { return }
    Task {
      await configured.configurationTask.value
      await configured.core.confirmPrivacyNotice()
    }
  }

  public func didEnterBackground() {
    guard let configured = runtime.configuredCore else { return }
    Task {
      await configured.configurationTask.value
      await configured.core.didEnterBackground()
    }
  }

  public func willEnterForeground() {
    guard let configured = runtime.configuredCore else { return }
    Task {
      await configured.configurationTask.value
      if await configured.core.willEnterForeground() {
        await FrictionFeedbackController.shared.beginSession()
      }
    }
  }

  func prepareFrictionFeedback(
    flow: AnalyticsFlow,
    fromScreen: AnalyticsScreen,
    trigger: FrictionTrigger
  ) async -> FrictionFeedbackContext? {
    guard let configured = runtime.configuredCore else { return nil }
    await configured.configurationTask.value
    return await configured.core.prepareFrictionFeedback(
      flow: flow, fromScreen: fromScreen, trigger: trigger)
  }
}

private final class AnalyticsRuntimeState: @unchecked Sendable {
  struct ConfiguredCore: Sendable {
    let core: AnalyticsCore
    let configurationTask: Task<Void, Never>
  }

  private let lock = NSLock()
  private var mode: AnalyticsMode = .disabled
  private var core: AnalyticsCore?
  private var task: Task<Void, Never>?

  var configuredCore: ConfiguredCore? {
    lock.withLock {
      guard case .live = mode, let core, let task else { return nil }
      return ConfiguredCore(core: core, configurationTask: task)
    }
  }

  func setMode(_ mode: AnalyticsMode) {
    lock.withLock { self.mode = mode }
  }

  func setCore(_ core: AnalyticsCore, configurationTask: Task<Void, Never>) {
    lock.withLock {
      self.core = core
      task = configurationTask
    }
  }

  func removeCore() {
    lock.withLock {
      task?.cancel()
      task = nil
      core = nil
    }
  }
}
