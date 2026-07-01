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
      if (error as? AuthRepositoryError)?.clearsBootstrapSession ?? false {
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
}

@available(iOS 17.0, macOS 14.0, *)
extension Session: SessionStateReader {
  public func accessToken() async throws -> String {
    guard let accessToken = await tokenStore.accessToken() else {
      throw SessionStateReaderError.missingAccessToken
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
