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
  @ObservationIgnored private var refreshTask: Task<String, Error>?

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
    state = .authenticating
    let refreshToken = await tokenStore.refreshToken()
    guard let refreshToken else {
      await tokenStore.clear()
      state = .anonymous
      return
    }

    guard let cachedUser = await tokenStore.cachedUser() else {
      await tokenStore.clear()
      state = .anonymous
      return
    }

    do {
      let tokens = try await auth.refresh(refreshToken: refreshToken)
      await tokenStore.save(access: tokens.accessToken, refresh: tokens.refreshToken)
      await tokenStore.saveUser(cachedUser)
      state = .authenticated(cachedUser)
    } catch {
      Self.logger.warning("bootstrap_refresh_failed \(String(describing: error))")
      // Only a server-confirmed invalid/expired refresh token should force logout. Transient
      // failures (offline, timeout, 5xx) must not: keep the stored credentials and stay signed
      // in on the cached user, so a flaky connection at launch doesn't boot the user to login.
      if Self.shouldClearSession(afterRefreshError: error) {
        await tokenStore.clear()
        state = .anonymous
      } else {
        state = .authenticated(cachedUser)
      }
    }
  }

  public func signup(phone: String, password: String, role: UserRole) async throws {
    state = .authenticating
    do {
      let result = try await auth.signup(phone: phone, password: password, role: role)
      await persist(result)
      state = .authenticated(result.user)
    } catch {
      state = .anonymous
      throw error
    }
  }

  public func login(phone: String, password: String) async throws {
    state = .authenticating
    do {
      let result = try await auth.login(phone: phone, password: password)
      await persist(result)
      state = .authenticated(result.user)
    } catch {
      state = .anonymous
      throw error
    }
  }

  public func logout() async {
    await tokenStore.clear()
    await onLogout?()
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

  private func persist(_ result: AuthResult) async {
    await tokenStore.save(access: result.accessToken, refresh: result.refreshToken)
    await tokenStore.saveUser(result.user)
  }

  private func refreshAccessToken() async throws -> String {
    if let refreshTask {
      return try await refreshTask.value
    }

    guard let refreshToken = await tokenStore.refreshToken() else {
      throw SessionStateReaderError.missingAccessToken
    }

    let task = Task { [auth, tokenStore] in
      let tokens = try await auth.refresh(refreshToken: refreshToken)
      await tokenStore.save(access: tokens.accessToken, refresh: tokens.refreshToken)
      return tokens.accessToken
    }
    refreshTask = task

    do {
      let token = try await task.value
      refreshTask = nil
      return token
    } catch {
      refreshTask = nil
      if Self.shouldClearSession(afterRefreshError: error) {
        await logout()
      }
      throw error
    }
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
    guard let accessToken = await tokenStore.accessToken() else {
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
