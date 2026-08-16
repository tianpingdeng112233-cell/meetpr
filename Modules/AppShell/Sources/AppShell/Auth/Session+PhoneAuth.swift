import CoreModels
import Foundation

@MainActor
@available(iOS 17.0, macOS 14.0, *)
extension Session {
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
}
