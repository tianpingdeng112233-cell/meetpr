#if !DEMO_MODE
  import AppShell
  import CoreModels
  import Foundation
  import Testing

  @testable import MeetPR

  @Test func deviceTokenHexEncodingIsLowercaseAndZeroPadded() {
    let data = Data([0x00, 0x01, 0x0a, 0x10, 0xab, 0xff])

    #expect(DeviceTokenHexEncoder.string(from: data) == "00010a10abff")
  }

  @MainActor
  @Test func staleAuthorizationErrorDoesNotClearNewCoachRequest() async throws {
    let coachA = makeUser(role: .coach)
    let coachB = makeUser(role: .coach)
    let authorization = AuthorizationProbe(
      states: [.notDetermined, .notDetermined],
      requestOutcomes: [.suspended, .suspended]
    )
    let promptStore = TestPromptStore()
    let coordinator = makeCoordinator(
      authorization: authorization,
      promptStore: promptStore
    )

    coordinator.activate(for: coachA)
    try await waitUntil { authorization.requestCount == 1 }
    coordinator.deactivate()
    coordinator.activate(for: coachB)
    try await waitUntil { authorization.requestCount == 2 }

    authorization.resumeFailure(call: 0)
    coordinator.activate(for: coachB)
    try await waitUntil { authorization.authorizationStateCallCount == 3 }

    #expect(authorization.requestCount == 2)

    authorization.resumeSuccess(call: 1, granted: false)
    try await waitUntil { await promptStore.hasRequestedAuthorization(for: coachB.id) }
  }

  @MainActor
  @Test func logoutCancelsInflightUploadAndDoesNotReassertWithoutCoach() async throws {
    let coach = makeUser(role: .coach)
    let authorization = AuthorizationProbe(states: [.authorized])
    let uploads = UploadProbe(outcomes: [.suspended])
    let coordinator = makeCoordinator(authorization: authorization, uploads: uploads)

    coordinator.activate(for: coach)
    coordinator.receiveDeviceToken(Data([0xab]))
    try await waitUntil { uploads.calls.count == 1 }

    coordinator.deactivate()
    uploads.resumeSuccess(call: 0)
    try await waitUntil { uploads.completedCalls.contains(0) }
    await Task.yield()

    #expect(uploads.wasCancelled[0] == true)
    #expect(uploads.calls.count == 1)
  }

  @MainActor
  @Test func staleUploadCompletionReassertsCachedTokenForCurrentCoach() async throws {
    let coachA = makeUser(role: .coach)
    let coachB = makeUser(role: .coach)
    let authorization = AuthorizationProbe(states: [.authorized, .notDetermined])
    let promptStore = TestPromptStore(markedAccountIDs: [coachB.id])
    let uploads = UploadProbe(outcomes: [.suspended, .success])
    let coordinator = makeCoordinator(
      authorization: authorization,
      promptStore: promptStore,
      uploads: uploads
    )

    coordinator.activate(for: coachA)
    coordinator.receiveDeviceToken(Data([0xab]))
    try await waitUntil { uploads.calls.count == 1 }

    coordinator.activate(for: coachB)
    try await waitUntil { authorization.authorizationStateCallCount == 2 }
    #expect(uploads.calls.count == 1)

    uploads.resumeSuccess(call: 0)
    try await waitUntil { uploads.calls.count == 2 }

    #expect(uploads.calls.map(\.accountID) == [coachA.id, coachB.id])
    #expect(uploads.calls.map(\.token) == ["ab", "ab"])
  }

  @MainActor
  @Test func deniedAuthorizationNeverPromptsSameAccountAgain() async throws {
    let coach = makeUser(role: .coach)
    let authorization = AuthorizationProbe(
      states: [.notDetermined, .notDetermined],
      requestOutcomes: [.denied]
    )
    let promptStore = TestPromptStore()
    let coordinator = makeCoordinator(
      authorization: authorization,
      promptStore: promptStore
    )

    coordinator.activate(for: coach)
    try await waitUntil { await promptStore.hasRequestedAuthorization(for: coach.id) }
    coordinator.activate(for: coach)
    try await waitUntil { authorization.authorizationStateCallCount == 2 }

    #expect(authorization.requestCount == 1)
    #expect(authorization.registrationCount == 0)
  }

  @MainActor
  @Test func changedDeviceTokenUploadsImmediately() async throws {
    let coach = makeUser(role: .coach)
    let authorization = AuthorizationProbe(states: [.authorized])
    let uploads = UploadProbe(outcomes: [.success, .success])
    let coordinator = makeCoordinator(authorization: authorization, uploads: uploads)

    coordinator.activate(for: coach)
    coordinator.receiveDeviceToken(Data([0xab]))
    try await waitUntil { uploads.completedCalls.contains(0) }
    coordinator.receiveDeviceToken(Data([0xcd]))
    try await waitUntil { uploads.completedCalls.contains(1) }

    #expect(uploads.calls.map(\.token) == ["ab", "cd"])
    #expect(uploads.calls.map(\.accountID) == [coach.id, coach.id])
  }

  @MainActor
  @Test func uploadFailureRetriesOnlyAfterLifecycleActivation() async throws {
    let coach = makeUser(role: .coach)
    let authorization = AuthorizationProbe(states: [.authorized, .authorized])
    let uploads = UploadProbe(outcomes: [.failure, .success])
    let coordinator = makeCoordinator(authorization: authorization, uploads: uploads)

    coordinator.activate(for: coach)
    coordinator.receiveDeviceToken(Data([0xab]))
    try await waitUntil { uploads.completedCalls.contains(0) }
    await Task.yield()

    #expect(uploads.calls.count == 1)

    coordinator.activate(for: coach)
    try await waitUntil { uploads.completedCalls.contains(1) }

    #expect(uploads.calls.map(\.token) == ["ab", "ab"])
  }

  @MainActor
  @Test func notificationBeforeDelegateConfigurationRoutesExactlyOnceAfterConfigure() {
    let appDelegate = MeetPRAppDelegate()
    let recorder = RouteRecorder()

    appDelegate.didReceiveNotification(
      categoryIdentifier: "coach_daily_digest",
      userInfo: [:]
    )
    #expect(recorder.routes.isEmpty)

    appDelegate.configure(
      routeHandler: { recorder.record($0) },
      deviceTokenHandler: { _ in }
    )
    appDelegate.configure(
      routeHandler: { recorder.record($0) },
      deviceTokenHandler: { _ in }
    )

    #expect(recorder.routes == [.coachToday])
  }

  @MainActor
  private func makeCoordinator(
    authorization: AuthorizationProbe,
    promptStore: TestPromptStore = TestPromptStore(),
    uploads: UploadProbe = UploadProbe(outcomes: [])
  ) -> PushRegistrationCoordinator {
    PushRegistrationCoordinator(
      notificationSystem: PushNotificationSystem(
        authorizationState: { authorization.authorizationState() },
        requestAuthorization: { try await authorization.requestAuthorization() },
        registerForRemoteNotifications: { authorization.registerForRemoteNotifications() }
      ),
      promptStore: promptStore,
      uploadToken: { token, accountID in
        try await uploads.upload(token: token, accountID: accountID)
      }
    )
  }

  private func makeUser(role: UserRole) -> User {
    User(
      id: UUID(),
      phone: "13800000000",
      unitSystem: .metric,
      role: role,
      createdAt: .now,
      updatedAt: .now
    )
  }

  private actor TestPromptStore: PushAuthorizationPromptStoring {
    private var markedAccountIDs: Set<UUID>

    init(markedAccountIDs: Set<UUID> = []) {
      self.markedAccountIDs = markedAccountIDs
    }

    func hasRequestedAuthorization(for accountID: UUID) -> Bool {
      markedAccountIDs.contains(accountID)
    }

    func markAuthorizationRequested(for accountID: UUID) {
      markedAccountIDs.insert(accountID)
    }
  }

  @MainActor
  private final class AuthorizationProbe {
    enum RequestOutcome {
      case granted
      case denied
      case failure
      case suspended
    }

    private var states: [PushAuthorizationState]
    private var requestOutcomes: [RequestOutcome]
    private var continuations: [Int: CheckedContinuation<Bool, any Error>] = [:]
    private(set) var authorizationStateCallCount = 0
    private(set) var requestCount = 0
    private(set) var registrationCount = 0

    init(
      states: [PushAuthorizationState],
      requestOutcomes: [RequestOutcome] = []
    ) {
      self.states = states
      self.requestOutcomes = requestOutcomes
    }

    func authorizationState() -> PushAuthorizationState {
      authorizationStateCallCount += 1
      guard states.count > 1 else { return states.first ?? .denied }
      return states.removeFirst()
    }

    func requestAuthorization() async throws -> Bool {
      let call = requestCount
      requestCount += 1
      let outcome = requestOutcomes.isEmpty ? .failure : requestOutcomes.removeFirst()
      switch outcome {
      case .granted:
        return true
      case .denied:
        return false
      case .failure:
        throw PushTestError.expected
      case .suspended:
        return try await withCheckedThrowingContinuation { continuation in
          continuations[call] = continuation
        }
      }
    }

    func registerForRemoteNotifications() {
      registrationCount += 1
    }

    func resumeSuccess(call: Int, granted: Bool) {
      continuations.removeValue(forKey: call)?.resume(returning: granted)
    }

    func resumeFailure(call: Int) {
      continuations.removeValue(forKey: call)?.resume(throwing: PushTestError.expected)
    }
  }

  @MainActor
  private final class UploadProbe {
    enum Outcome {
      case success
      case failure
      case suspended
    }

    struct Call: Equatable {
      let token: String
      let accountID: UUID
    }

    private var outcomes: [Outcome]
    private var continuations: [Int: CheckedContinuation<Void, any Error>] = [:]
    private(set) var calls: [Call] = []
    private(set) var completedCalls: Set<Int> = []
    private(set) var wasCancelled: [Int: Bool] = [:]

    init(outcomes: [Outcome]) {
      self.outcomes = outcomes
    }

    func upload(token: String, accountID: UUID) async throws {
      let call = calls.count
      calls.append(Call(token: token, accountID: accountID))
      defer {
        completedCalls.insert(call)
        wasCancelled[call] = Task.isCancelled
      }

      let outcome = outcomes.isEmpty ? .success : outcomes.removeFirst()
      switch outcome {
      case .success:
        return
      case .failure:
        throw PushTestError.expected
      case .suspended:
        try await withCheckedThrowingContinuation { continuation in
          continuations[call] = continuation
        }
      }
    }

    func resumeSuccess(call: Int) {
      continuations.removeValue(forKey: call)?.resume(returning: ())
    }
  }

  @MainActor
  private final class RouteRecorder {
    private(set) var routes: [AppRoute] = []

    func record(_ route: AppRoute) {
      routes.append(route)
    }
  }

  private enum PushTestError: Error {
    case expected
    case timedOut
  }

  @MainActor
  private func waitUntil(
    timeoutMilliseconds: Int = 2_000,
    _ condition: @MainActor () async -> Bool
  ) async throws {
    for _ in 0..<(timeoutMilliseconds / 10) {
      if await condition() { return }
      try await Task.sleep(for: .milliseconds(10))
    }
    throw PushTestError.timedOut
  }
#endif
