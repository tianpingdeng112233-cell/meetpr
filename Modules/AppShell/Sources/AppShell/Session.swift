import CoreModels
import Foundation
import Networking
import Observation

@Observable
@MainActor
@available(iOS 17.0, macOS 14.0, *)
public final class Session {
  public enum State: Equatable, Sendable {
    case anonymous
    case authenticating
    case authenticated(User)
  }

  public private(set) var state: State = .anonymous
  @ObservationIgnored private let api: APIClient

  public init(api: APIClient) {
    self.api = api
  }

  public func fakeLogin(role: UserRole) {
    let now = Date()
    let user = User(
      id: UUID(),
      phone: "00000000000",
      name: "Test User",
      unitSystem: .metric,
      role: role,
      createdAt: now,
      updatedAt: now
    )
    state = .authenticated(user)
  }

  public func logout() {
    state = .anonymous
  }
}
