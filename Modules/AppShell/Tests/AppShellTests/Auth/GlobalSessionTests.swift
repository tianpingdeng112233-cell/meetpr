import CoreModels
import Foundation
import Testing

@testable import AppShell

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func bootstrapReportsTimezoneOnlyWhenItDrifts() async {
  let user = AuthTestSupport.user(role: .coachedStudent, phone: "athlete@example.com")
  let repository = GlobalAuthRepositorySpy(user: user)
  let timezoneStore = InMemoryTimezoneStore(
    reportedIdentifiers: [user.id: "Asia/Shanghai"])
  let tokenStore = InMemoryTokenStore(access: "old-access", refresh: "old-refresh", user: user)
  let session = Session(
    auth: repository,
    tokenStore: tokenStore,
    timezoneStore: timezoneStore,
    currentTimezoneIdentifier: { "Europe/London" },
    reportsTimezoneOnBootstrap: true
  )

  await session.bootstrap()

  #expect(session.state == .authenticated(user))
  #expect(await repository.timezoneUpdates() == ["Europe/London:new-access"])
  #expect(await timezoneStore.lastReportedIdentifier(for: user.id) == "Europe/London")
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func bootstrapSkipsTimezonePatchWhenIdentifierMatches() async {
  let user = AuthTestSupport.user(role: .coachedStudent, phone: "athlete@example.com")
  let repository = GlobalAuthRepositorySpy(user: user)
  let timezoneStore = InMemoryTimezoneStore(
    reportedIdentifiers: [user.id: "Europe/London"])
  let session = Session(
    auth: repository,
    tokenStore: InMemoryTokenStore(access: "old-access", refresh: "old-refresh", user: user),
    timezoneStore: timezoneStore,
    currentTimezoneIdentifier: { "Europe/London" },
    reportsTimezoneOnBootstrap: true
  )

  await session.bootstrap()

  #expect(await repository.timezoneUpdates().isEmpty)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func chinaBootstrapNeverReportsTimezone() async {
  let user = AuthTestSupport.user(role: .coachedStudent)
  let repository = GlobalAuthRepositorySpy(user: user)
  let session = Session(
    auth: repository,
    tokenStore: InMemoryTokenStore(access: "old-access", refresh: "old-refresh", user: user),
    timezoneStore: InMemoryTimezoneStore(
      reportedIdentifiers: [user.id: "Asia/Shanghai"]),
    currentTimezoneIdentifier: { "Europe/London" },
    reportsTimezoneOnBootstrap: false
  )

  await session.bootstrap()

  #expect(session.state == .authenticated(user))
  #expect(await repository.timezoneUpdates().isEmpty)
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func globalRegistrationPassesCurrentTimezoneAndPersistsIt() async throws {
  let user = AuthTestSupport.user(role: .coachedStudent, phone: "athlete@example.com")
  let repository = GlobalAuthRepositorySpy(user: user)
  let timezoneStore = InMemoryTimezoneStore()
  let session = Session(
    auth: repository,
    tokenStore: InMemoryTokenStore(),
    timezoneStore: timezoneStore,
    currentTimezoneIdentifier: { "Europe/London" },
    reportsTimezoneOnBootstrap: true
  )

  try await session.registerWithEmail(email: "athlete@example.com", password: "password123")

  #expect(await repository.registeredTimezone() == "Europe/London")
  #expect(await timezoneStore.lastReportedIdentifier(for: user.id) == "Europe/London")
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test(arguments: InteractiveLoginChannel.allCases)
func returningUserLoginReportsDriftedTimezoneBeforePersistingMarker(
  channel: InteractiveLoginChannel
) async throws {
  let user = AuthTestSupport.user(role: .coachedStudent, phone: "athlete@example.com")
  let repository = GlobalAuthRepositorySpy(user: user)
  let timezoneStore = InMemoryTimezoneStore(
    reportedIdentifiers: [user.id: "Asia/Shanghai"])
  let session = Session(
    auth: repository,
    tokenStore: InMemoryTokenStore(),
    timezoneStore: timezoneStore,
    currentTimezoneIdentifier: { "Europe/London" },
    reportsTimezoneOnBootstrap: true
  )

  try await channel.signIn(using: session)

  #expect(session.state == .authenticated(user))
  #expect(await repository.timezoneUpdates() == ["Europe/London:access"])
  #expect(await timezoneStore.lastReportedIdentifier(for: user.id) == "Europe/London")
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test(arguments: InteractiveLoginChannel.allCases)
func returningUserLoginLeavesTimezoneMarkerUnchangedWhenPatchFails(
  channel: InteractiveLoginChannel
) async throws {
  let user = AuthTestSupport.user(role: .coachedStudent, phone: "athlete@example.com")
  let repository = GlobalAuthRepositorySpy(user: user, timezoneUpdateError: .network)
  let timezoneStore = InMemoryTimezoneStore(
    reportedIdentifiers: [user.id: "Asia/Shanghai"])
  let session = Session(
    auth: repository,
    tokenStore: InMemoryTokenStore(),
    timezoneStore: timezoneStore,
    currentTimezoneIdentifier: { "Europe/London" },
    reportsTimezoneOnBootstrap: true
  )

  try await channel.signIn(using: session)

  #expect(session.state == .authenticated(user))
  #expect(await repository.timezoneUpdates() == ["Europe/London:access"])
  #expect(await timezoneStore.lastReportedIdentifier(for: user.id) == "Asia/Shanghai")
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func accountSwitchReportsTimezoneForEachUserOnTheSameDevice() async throws {
  let userA = AuthTestSupport.user(
    id: UUID(uuidString: "00000000-0000-0000-0000-0000000000A1") ?? UUID(),
    role: .coachedStudent,
    phone: "athlete-a@example.com"
  )
  let userB = AuthTestSupport.user(
    id: UUID(uuidString: "00000000-0000-0000-0000-0000000000B2") ?? UUID(),
    role: .coachedStudent,
    phone: "athlete-b@example.com"
  )
  let suiteName = "GlobalSessionTests.accountSwitch.\(UUID().uuidString)"
  let defaults = try #require(UserDefaults(suiteName: suiteName))
  defer { defaults.removePersistentDomain(forName: suiteName) }
  let timezoneStore = UserDefaultsTimezoneStore(suiteName: suiteName)
  let repository = GlobalAuthRepositorySpy(user: userA, emailLoginUsers: [userA, userB])
  let session = Session(
    auth: repository,
    tokenStore: InMemoryTokenStore(),
    timezoneStore: timezoneStore,
    currentTimezoneIdentifier: { "Europe/London" },
    reportsTimezoneOnBootstrap: true
  )

  try await session.loginWithEmail(email: userA.phone, password: "password123")
  await session.logout()
  try await session.loginWithEmail(email: userB.phone, password: "password123")

  #expect(await repository.timezoneUpdates().count == 2)
  #expect(await timezoneStore.lastReportedIdentifier(for: userA.id) == "Europe/London")
  #expect(await timezoneStore.lastReportedIdentifier(for: userB.id) == "Europe/London")
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func foregroundReportsChangedTimezoneOnceAndSkipsUnchangedValue() async throws {
  let user = AuthTestSupport.user(role: .coachedStudent, phone: "athlete@example.com")
  let repository = GlobalAuthRepositorySpy(user: user)
  let timezoneStore = InMemoryTimezoneStore(
    reportedIdentifiers: [user.id: "Europe/London"])
  let timezone = LockedTimezoneIdentifier("Europe/London")
  let session = Session(
    auth: repository,
    tokenStore: InMemoryTokenStore(),
    timezoneStore: timezoneStore,
    currentTimezoneIdentifier: { timezone.value() },
    reportsTimezoneOnBootstrap: true
  )
  try await session.loginWithEmail(email: user.phone, password: "password123")

  timezone.setValue("America/New_York")
  await session.applicationDidBecomeActive()
  await session.applicationDidBecomeActive()

  #expect(await repository.timezoneUpdates() == ["America/New_York:access"])
  #expect(
    await timezoneStore.lastReportedIdentifier(for: user.id) == "America/New_York"
  )
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func failedForegroundTimezoneReportRetriesAtNextActivation() async throws {
  let user = AuthTestSupport.user(role: .coachedStudent, phone: "athlete@example.com")
  let repository = GlobalAuthRepositorySpy(user: user, timezoneUpdateError: .network)
  let timezoneStore = InMemoryTimezoneStore(
    reportedIdentifiers: [user.id: "Europe/London"])
  let timezone = LockedTimezoneIdentifier("Europe/London")
  let session = Session(
    auth: repository,
    tokenStore: InMemoryTokenStore(),
    timezoneStore: timezoneStore,
    currentTimezoneIdentifier: { timezone.value() },
    reportsTimezoneOnBootstrap: true
  )
  try await session.loginWithEmail(email: user.phone, password: "password123")

  timezone.setValue("America/New_York")
  await session.applicationDidBecomeActive()
  await session.applicationDidBecomeActive()

  #expect(
    await repository.timezoneUpdates()
      == ["America/New_York:access", "America/New_York:access"]
  )
  #expect(await timezoneStore.lastReportedIdentifier(for: user.id) == "Europe/London")
}

private final class LockedTimezoneIdentifier: @unchecked Sendable {
  private let lock = NSLock()
  private var identifier: String

  init(_ identifier: String) {
    self.identifier = identifier
  }

  func value() -> String {
    lock.withLock { identifier }
  }

  func setValue(_ identifier: String) {
    lock.withLock { self.identifier = identifier }
  }
}

enum InteractiveLoginChannel: CaseIterable, Sendable {
  case apple
  case google
  case email

  @MainActor
  func signIn(using session: Session) async throws {
    switch self {
    case .apple:
      try await session.signInWithApple(
        identityToken: "apple-token",
        nonce: "challenge",
        authorizationCode: "authorization-code"
      )
    case .google:
      try await session.signInWithGoogle(idToken: "google-token")
    case .email:
      try await session.loginWithEmail(email: "athlete@example.com", password: "password123")
    }
  }
}

private actor InMemoryTimezoneStore: TimezoneStoring {
  private var reportedIdentifiers: [UUID: String]

  init(reportedIdentifiers: [UUID: String] = [:]) {
    self.reportedIdentifiers = reportedIdentifiers
  }

  func lastReportedIdentifier(for userID: UUID) -> String? {
    reportedIdentifiers[userID]
  }

  func saveReportedIdentifier(_ identifier: String, for userID: UUID) {
    reportedIdentifiers[userID] = identifier
  }
}

private actor GlobalAuthRepositorySpy: AuthRepository {
  private let result: AuthResult
  private let timezoneUpdateError: AuthRepositoryError?
  private var emailLoginResults: [AuthResult]
  private var updates: [String] = []
  private var registrationTimezone: String?

  init(
    user: User,
    emailLoginUsers: [User] = [],
    timezoneUpdateError: AuthRepositoryError? = nil
  ) {
    result = AuthResult(user: user, accessToken: "access", refreshToken: "refresh")
    emailLoginResults = emailLoginUsers.map {
      AuthResult(user: $0, accessToken: "access", refreshToken: "refresh")
    }
    self.timezoneUpdateError = timezoneUpdateError
  }

  func signup(phone: String, password: String, role: UserRole) async throws -> AuthResult {
    result
  }

  func login(phone: String, password: String) async throws -> AuthResult {
    result
  }

  func fetchChallenge() async throws -> AuthChallenge {
    AuthChallenge(nonce: "challenge", expiresAt: Date().addingTimeInterval(600))
  }

  func signInWithApple(
    identityToken: String,
    nonce: String,
    authorizationCode: String?,
    timezone: String
  ) async throws -> AuthResult {
    result
  }

  func signInWithGoogle(idToken: String, timezone: String) async throws -> AuthResult {
    result
  }

  func registerWithEmail(
    email: String,
    password: String,
    timezone: String
  ) async throws -> AuthResult {
    registrationTimezone = timezone
    return result
  }

  func loginWithEmail(email: String, password: String) async throws -> AuthResult {
    if !emailLoginResults.isEmpty {
      return emailLoginResults.removeFirst()
    }
    return result
  }

  func requestPasswordReset(email: String) async throws {}

  func resetPassword(email: String, code: String, newPassword: String) async throws {}

  func updateTimezone(_ timezone: String, accessToken: String) async throws {
    updates.append("\(timezone):\(accessToken)")
    if let timezoneUpdateError {
      throw timezoneUpdateError
    }
  }

  func refresh(refreshToken: String) async throws -> TokenPair {
    TokenPair(accessToken: "new-access", refreshToken: "new-refresh")
  }

  func timezoneUpdates() -> [String] {
    updates
  }

  func registeredTimezone() -> String? {
    registrationTimezone
  }
}
