import Foundation

struct AnalyticsConfiguration: Sendable {
  let baseURL: URL
  let transport: EventTransport
  let accessTokenProvider: @Sendable () async -> String?
  let mode: AnalyticsMode
  let privacyNoticeConfirmed: Bool
  let appVersion: String
  let build: String
  let crashDirectory: URL
}

struct FrictionFeedbackContext: Sendable {
  let eventID: UUID
  let anonID: UUID
  let sessionID: UUID
}

actor AnalyticsCore {
  private let queue: EventQueueStore
  private let session: AnalyticsSessionStore
  private let now: @Sendable () -> Date
  private let installCrashCapture: @Sendable (URL, CrashContext) -> PendingCrash?
  private let updateCrashCapture: @Sendable (CrashContext) -> Void
  private var mode: AnalyticsMode = .live
  private var collectionEnabled = true
  private var lastScreen = AnalyticsScreen.dashboard
  private var flusher: EventFlusher?
  private var feedbackContexts: [UUID: AnalyticsSessionStore.Metadata] = [:]

  init(
    queue: EventQueueStore = EventQueueStore(),
    session: AnalyticsSessionStore = AnalyticsSessionStore(),
    now: @escaping @Sendable () -> Date = { Date() },
    installCrashCapture: @escaping @Sendable (URL, CrashContext) -> PendingCrash? = {
      CrashCapture.install(directory: $0, context: $1)
    },
    updateCrashCapture: @escaping @Sendable (CrashContext) -> Void = {
      CrashCapture.updateContext($0)
    }
  ) {
    self.queue = queue
    self.session = session
    self.now = now
    self.installCrashCapture = installCrashCapture
    self.updateCrashCapture = updateCrashCapture
  }

  func configure(_ configuration: AnalyticsConfiguration) async {
    mode = configuration.mode
    guard case .live = configuration.mode else {
      collectionEnabled = false
      flusher = nil
      return
    }
    collectionEnabled = true
    let flusher = EventFlusher(
      queue: queue,
      baseURL: configuration.baseURL,
      transport: configuration.transport,
      accessTokenProvider: configuration.accessTokenProvider,
      session: session,
      appVersion: configuration.appVersion,
      build: configuration.build,
      privacyGateOpen: configuration.privacyNoticeConfirmed
    )
    self.flusher = flusher
    await flusher.start()
    let metadata = await session.current()
    let crashContext = CrashContext(
      anonID: metadata.anonID, sessionID: metadata.sessionID, screen: lastScreen)
    if let pendingCrash = installCrashCapture(configuration.crashDirectory, crashContext) {
      _ = await enqueue(
        .clientError,
        sessionID: pendingCrash.context.sessionID,
        props: [
          "domain": .enumCase(ClientErrorDomain.unknown),
          "code": .int(Int(pendingCrash.signalNumber)),
          "screen": .enumCase(pendingCrash.context.screen),
        ])
    }
  }

  func track(_ name: AnalyticsEvent, props: [String: AnalyticsValue]) async {
    guard collectionEnabled, case .live = mode else { return }
    let metadata = await enqueue(name, props: props)
    if name == .screenView, case .enumCase(let rawScreen) = props["screen"],
      let screen = AnalyticsScreen(rawValue: rawScreen), let metadata
    {
      lastScreen = screen
      let context = CrashContext(
        anonID: metadata.anonID, sessionID: metadata.sessionID, screen: screen)
      updateCrashCapture(context)
      await flusher?.updateScreen(screen)
    }
    if name == .appOpen, let flusher {
      collectionEnabled = await flusher.fetchConfig()
      if collectionEnabled { await flusher.flush() }
    }
  }

  func prepareFrictionFeedback(
    flow: AnalyticsFlow,
    fromScreen: AnalyticsScreen,
    trigger: FrictionTrigger
  ) async -> FrictionFeedbackContext? {
    guard collectionEnabled, case .live = mode else { return nil }
    let eventID = UUID()
    guard
      let metadata = await enqueue(
        .frictionFeedback,
        eventID: eventID,
        props: [
          "flow": .enumCase(flow),
          "from_screen": .enumCase(fromScreen),
          "trigger": .enumCase(trigger),
        ])
    else { return nil }
    feedbackContexts[eventID] = metadata
    return FrictionFeedbackContext(
      eventID: eventID, anonID: metadata.anonID, sessionID: metadata.sessionID)
  }

  func submitFrictionText(
    eventID: UUID,
    flow: AnalyticsFlow,
    fromScreen: AnalyticsScreen,
    trigger: FrictionTrigger,
    text: String
  ) async {
    guard collectionEnabled, case .live = mode else { return }
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else { return }
    let safeText = String(trimmed.prefix(500))
    let metadata: AnalyticsSessionStore.Metadata
    if let context = feedbackContexts.removeValue(forKey: eventID) {
      metadata = context
    } else {
      metadata = await session.current()
    }
    await queue.enqueue(
      FrictionFeedbackPayload(
        eventID: eventID,
        anonID: metadata.anonID,
        sessionID: metadata.sessionID,
        flow: flow,
        fromScreen: fromScreen,
        trigger: trigger,
        text: safeText,
        timestamp: now()
      ))
    await flusher?.flush()
  }

  func confirmPrivacyNotice() async {
    await flusher?.setPrivacyGate(open: true)
  }

  func didEnterBackground() async {
    await session.didEnterBackground()
  }

  func willEnterForeground() async -> Bool {
    let before = await session.current().sessionID
    await session.willEnterForeground()
    let after = await session.current().sessionID
    let metadata = await session.current()
    updateCrashCapture(
      CrashContext(
        anonID: metadata.anonID, sessionID: metadata.sessionID, screen: lastScreen))
    await flusher?.flush()
    return before != after
  }

  private func enqueue(
    _ name: AnalyticsEvent,
    eventID: UUID = UUID(),
    sessionID: UUID? = nil,
    props: [String: AnalyticsValue]
  ) async -> AnalyticsSessionStore.Metadata? {
    guard let propsData = try? JSONEncoder().encode(props), propsData.count <= 4_096 else {
      return nil
    }
    let metadata = await session.next()
    let event = AnalyticsEnvelope(
      eventID: eventID,
      sessionID: sessionID ?? metadata.sessionID,
      seq: metadata.seq,
      name: name,
      props: props,
      schemaVersion: 1,
      timestamp: now()
    )
    await queue.enqueue(event)
    #if DEBUG
      print("[Analytics] track \(name.rawValue) \(props)")
    #endif
    return metadata
  }
}
