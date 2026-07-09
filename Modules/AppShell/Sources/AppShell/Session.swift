// swiftlint:disable sorted_imports
import CoreModels
import Foundation
import Networking
import OSLog
import Observation

// swiftlint:enable sorted_imports

@Observable
@MainActor
@available(iOS 17.0, macOS 14.0, *)
public final class Session {
  public enum State: Equatable, Sendable {
    case anonymous
    case authenticating
    case authenticated(User)
  }

  @ObservationIgnored
  private static let logger = Logger(subsystem: "com.meetpr.app.appshell", category: "auth")

  public private(set) var state: State = .anonymous

  @ObservationIgnored private let auth: any AuthRepository
  @ObservationIgnored private let tokenStore: any TokenStoring
  @ObservationIgnored private let onLogout: (@Sendable () async -> Void)?
  @ObservationIgnored private var errorTask: Task<Void, Never>?
  @ObservationIgnored private var refreshTask: Task<TokenPair, Error>?
  /// Every login/bootstrap/logout gets a new generation. Completion handlers
  /// must match it before they are allowed to write credentials or UI state.
  @ObservationIgnored private var sessionGeneration: UInt = 0

  public init(
    auth: any AuthRepository,
    tokenStore: any TokenStoring,
    onLogout: (@Sendable () async -> Void)? = nil
  ) {
    self.auth = auth
    self.tokenStore = tokenStore
    self.onLogout = onLogout
  }

  public func bootstrap() async {
    // The root `.task` calls bootstrap() unconditionally. Once an interactive
    // login/signup has settled the session, never re-run the silent-refresh
    // flow: driving an authenticated session back through `.authenticating`
    // tears down the signed-in subtree and cancels the student tabs' in-flight
    // first-load `.task`s, which then surface as a spurious "cancelled" error
    // on high-latency networks. Bootstrap only ever runs from a cold start.
    guard case .anonymous = state else { return }
    let generation = beginSessionTransition()
    state = .authenticating
    let refreshToken = await tokenStore.refreshToken()
    guard isCurrentSession(generation) else { return }
    guard let refreshToken else {
      await tokenStore.clear()
      guard isCurrentSession(generation) else { return }
      state = .anonymous
      return
    }

    guard let cachedUser = await tokenStore.cachedUser() else {
      await tokenStore.clear()
      guard isCurrentSession(generation) else { return }
      state = .anonymous
      return
    }

    do {
      let tokens = try await auth.refresh(refreshToken: refreshToken)
      guard isCurrentSession(generation) else { return }
      await tokenStore.save(access: tokens.accessToken, refresh: tokens.refreshToken)
      guard isCurrentSession(generation) else { return }
      await tokenStore.saveUser(cachedUser)
      guard isCurrentSession(generation) else { return }
      state = .authenticated(cachedUser)
    } catch {
      guard isCurrentSession(generation) else { return }
      Self.logger.warning("bootstrap_refresh_failed \(String(describing: error))")
      // Only a server-confirmed invalid/expired refresh token should force logout. Transient
      // failures (offline, timeout, 5xx) must not: keep the stored credentials and stay signed
      // in on the cached user, so a flaky connection at launch doesn't boot the user to login.
      if Self.shouldClearSession(afterRefreshError: error) {
        await tokenStore.clear()
        guard isCurrentSession(generation) else { return }
        state = .anonymous
      } else {
        state = .authenticated(cachedUser)
      }
    }
  }

  public func signup(phone: String, password: String, role: UserRole) async throws {
    let generation = beginSessionTransition()
    state = .authenticating
    await tokenStore.clear()
    guard isCurrentSession(generation) else { throw CancellationError() }
    do {
      let result = try await auth.signup(phone: phone, password: password, role: role)
      guard isCurrentSession(generation) else { throw CancellationError() }
      guard await persist(result, generation: generation) else { throw CancellationError() }
      state = .authenticated(result.user)
    } catch {
      guard isCurrentSession(generation) else { throw error }
      await tokenStore.clear()
      guard isCurrentSession(generation) else { throw error }
      state = .anonymous
      throw error
    }
  }

  public func login(phone: String, password: String) async throws {
    let generation = beginSessionTransition()
    state = .authenticating
    await tokenStore.clear()
    guard isCurrentSession(generation) else { throw CancellationError() }
    do {
      let result = try await auth.login(phone: phone, password: password)
      guard isCurrentSession(generation) else { throw CancellationError() }
      guard await persist(result, generation: generation) else { throw CancellationError() }
      state = .authenticated(result.user)
    } catch {
      guard isCurrentSession(generation) else { throw error }
      await tokenStore.clear()
      guard isCurrentSession(generation) else { throw error }
      state = .anonymous
      throw error
    }
  }

  public func logout() async {
    let generation = beginSessionTransition()
    await tokenStore.clear()
    guard isCurrentSession(generation) else { return }
    await onLogout?()
    guard isCurrentSession(generation) else { return }
    state = .anonymous
  }

  public func bindToErrors(_ errorStream: AsyncStream<APIError>) {
    errorTask?.cancel()
    errorTask = Task { [weak self] in
      for await error in errorStream {
        guard case .authInvalid = error else { continue }
        await self?.logout()
      }
    }
  }

  public func recoverAccessToken(rejectedAccessToken: String) async throws -> String {
    let generation = sessionGeneration
    guard case .authenticated = state else {
      throw SessionStateReaderError.missingAccessToken
    }
    guard let currentAccessToken = await tokenStore.accessToken() else {
      guard isCurrentSession(generation) else {
        throw SessionStateReaderError.missingAccessToken
      }
      await logout()
      throw SessionStateReaderError.missingAccessToken
    }
    guard isCurrentSession(generation) else {
      throw SessionStateReaderError.missingAccessToken
    }

    // A concurrent request may already have rotated the token after this
    // request was sent. Reuse that token instead of rotating refresh tokens again.
    if currentAccessToken != rejectedAccessToken {
      return currentAccessToken
    }
    return try await refreshAccessToken()
  }

  private func persist(_ result: AuthResult, generation: UInt) async -> Bool {
    guard isCurrentSession(generation) else { return false }
    await tokenStore.save(access: result.accessToken, refresh: result.refreshToken)
    guard isCurrentSession(generation) else { return false }
    await tokenStore.saveUser(result.user)
    return isCurrentSession(generation)
  }

  private func refreshAccessToken() async throws -> String {
    let generation = sessionGeneration
    let task: Task<TokenPair, Error>
    if let refreshTask {
      task = refreshTask
    } else {
      guard let refreshToken = await tokenStore.refreshToken() else {
        throw SessionStateReaderError.missingAccessToken
      }
      guard isCurrentSession(generation) else { throw CancellationError() }

      task = Task { [auth] in
        try await auth.refresh(refreshToken: refreshToken)
      }
      refreshTask = task
    }

    do {
      let tokens = try await task.value
      guard isCurrentSession(generation) else { throw CancellationError() }
      await tokenStore.save(access: tokens.accessToken, refresh: tokens.refreshToken)
      guard isCurrentSession(generation) else { throw CancellationError() }
      refreshTask = nil
      return tokens.accessToken
    } catch {
      guard isCurrentSession(generation) else { throw error }
      refreshTask = nil
      if Self.shouldClearSession(afterRefreshError: error) {
        await logout()
      }
      throw error
    }
  }

  private func beginSessionTransition() -> UInt {
    sessionGeneration &+= 1
    refreshTask?.cancel()
    refreshTask = nil
    return sessionGeneration
  }

  private func isCurrentSession(_ generation: UInt) -> Bool {
    generation == sessionGeneration
  }

  private static func shouldClearSession(afterRefreshError error: Error) -> Bool {
    guard let authError = error as? AuthRepositoryError else {
      return false
    }
    return authError.clearsBootstrapSession
  }

  private static func shouldRefresh(accessToken: String, now: Date = Date()) -> Bool {
    guard let expiration = expirationDate(fromJWT: accessToken) else {
      return false
    }
    return expiration.timeIntervalSince(now) <= 60
  }

  private static func expirationDate(fromJWT token: String) -> Date? {
    let segments = token.split(separator: ".")
    guard
      segments.count >= 2,
      let data = base64URLDecoded(String(segments[1])),
      let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let exp = object["exp"] as? TimeInterval
    else {
      return nil
    }
    return Date(timeIntervalSince1970: exp)
  }

  private static func base64URLDecoded(_ value: String) -> Data? {
    var base64 =
      value
      .replacingOccurrences(of: "-", with: "+")
      .replacingOccurrences(of: "_", with: "/")
    let padding = base64.count % 4
    if padding > 0 {
      base64 += String(repeating: "=", count: 4 - padding)
    }
    return Data(base64Encoded: base64)
  }
}

@available(iOS 17.0, macOS 14.0, *)
extension Session: SessionStateReader {
  public func accessToken() async throws -> String {
    let generation = sessionGeneration
    guard case .authenticated = state else {
      throw SessionStateReaderError.missingAccessToken
    }
    guard let accessToken = await tokenStore.accessToken() else {
      throw SessionStateReaderError.missingAccessToken
    }
    guard isCurrentSession(generation) else {
      throw SessionStateReaderError.missingAccessToken
    }
    if Self.shouldRefresh(accessToken: accessToken) {
      return try await refreshAccessToken()
    }
    return accessToken
  }

  public func currentUser() async throws -> User {
    switch state {
    case .authenticated(let user):
      return user
    case .anonymous, .authenticating:
      throw SessionStateReaderError.missingCurrentUser
    }
  }
}

@available(iOS 17.0, macOS 14.0, *)
extension Session: @unchecked Sendable {}
