import Foundation

@MainActor
@available(iOS 17.0, macOS 14.0, *)
extension Session {
  public func fetchAuthChallenge() async throws -> AuthChallenge {
    try await auth.fetchChallenge()
  }

  public func signInWithApple(
    identityToken: String,
    nonce: String,
    authorizationCode: String?
  ) async throws {
    let timezone = currentTimezoneIdentifier()
    let result = try await authenticate {
      try await auth.signInWithApple(
        identityToken: identityToken,
        nonce: nonce,
        authorizationCode: authorizationCode,
        timezone: timezone
      )
    }
    await reportTimezoneAfterLoginIfNeeded(result: result, timezone: timezone)
  }

  public func signInWithGoogle(idToken: String) async throws {
    let timezone = currentTimezoneIdentifier()
    let result = try await authenticate {
      try await auth.signInWithGoogle(idToken: idToken, timezone: timezone)
    }
    await reportTimezoneAfterLoginIfNeeded(result: result, timezone: timezone)
  }

  public func registerWithEmail(email: String, password: String) async throws {
    let timezone = currentTimezoneIdentifier()
    let result = try await authenticate {
      try await auth.registerWithEmail(email: email, password: password, timezone: timezone)
    }
    await timezoneStore.saveReportedIdentifier(timezone, for: result.user.id)
  }

  public func loginWithEmail(email: String, password: String) async throws {
    let result = try await authenticate {
      try await auth.loginWithEmail(email: email, password: password)
    }
    let timezone = currentTimezoneIdentifier()
    await reportTimezoneAfterLoginIfNeeded(result: result, timezone: timezone)
  }

  private func reportTimezoneAfterLoginIfNeeded(result: AuthResult, timezone: String) async {
    let userID = result.user.id
    let lastReportedTimezone = await timezoneStore.lastReportedIdentifier(for: userID)
    guard lastReportedTimezone != timezone else { return }
    do {
      try await auth.updateTimezone(timezone, accessToken: result.accessToken)
      await timezoneStore.saveReportedIdentifier(timezone, for: userID)
    } catch {
      Self.logger.warning("login_timezone_update_failed \(String(describing: error))")
    }
  }

  public func requestPasswordReset(email: String) async throws {
    try await auth.requestPasswordReset(email: email)
  }

  public func resetPassword(email: String, code: String, newPassword: String) async throws {
    try await auth.resetPassword(email: email, code: code, newPassword: newPassword)
  }

  func reportTimezoneIfNeeded(userID: UUID, accessToken: String, generation: UInt) async {
    let timezone = currentTimezoneIdentifier()
    let lastReportedTimezone = await timezoneStore.lastReportedIdentifier(for: userID)
    guard isCurrentSession(generation), lastReportedTimezone != timezone else { return }
    do {
      try await auth.updateTimezone(timezone, accessToken: accessToken)
      guard isCurrentSession(generation) else { return }
      await timezoneStore.saveReportedIdentifier(timezone, for: userID)
    } catch {
      Self.logger.warning("bootstrap_timezone_update_failed \(String(describing: error))")
    }
  }

  @discardableResult
  private func authenticate(
    using operation: () async throws -> AuthResult
  ) async throws -> AuthResult {
    // Unlike the CN phone flow this stays in `.anonymous` while the attempt is
    // in flight: flipping to `.authenticating` swaps RootView away from the
    // login screen, so a failure remounts GlobalLoginView and silently drops
    // the error toast (2026-08-16 device smoke). The Global login buttons show
    // their own progress state; only success changes the session state.
    let generation = beginSessionTransition()
    await tokenStore.clear()
    guard isCurrentSession(generation) else { throw CancellationError() }
    do {
      let result = try await operation()
      guard isCurrentSession(generation) else { throw CancellationError() }
      guard await persist(result, generation: generation) else { throw CancellationError() }
      state = .authenticated(result.user)
      return result
    } catch {
      guard isCurrentSession(generation) else { throw error }
      await tokenStore.clear()
      throw error
    }
  }
}
