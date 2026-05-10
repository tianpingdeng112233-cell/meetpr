// swiftlint:disable sorted_imports
import CoreModels
import Foundation
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
    let accessToken = await tokenStore.accessToken()
    let refreshToken = await tokenStore.refreshToken()
    let cachedUser = await tokenStore.cachedUser()

    guard accessToken != nil, let refreshToken, let cachedUser else {
      await tokenStore.clear()
      state = .anonymous
      return
    }

    state = .authenticated(cachedUser)

    do {
      let tokens = try await auth.refresh(refreshToken: refreshToken)
      await tokenStore.save(access: tokens.accessToken, refresh: tokens.refreshToken)
    } catch {
      if let authError = error as? AuthRepositoryError, authError.clearsBootstrapSession {
        await tokenStore.clear()
        state = .anonymous
      } else {
        Self.logger.warning("bootstrap_refresh_deferred \(String(describing: error))")
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

  private func persist(_ result: AuthResult) async {
    await tokenStore.save(access: result.accessToken, refresh: result.refreshToken)
    await tokenStore.saveUser(result.user)
  }
}
