import CoreModels
import Foundation

@available(iOS 17.0, macOS 14.0, *)
public actor DemoTokenStore: TokenStoring {
  public init() {}

  public func save(access: String, refresh: String) async {}

  public func saveUser(_ user: User) async {}

  public func accessToken() async -> String? {
    DemoUserSeed.accessToken
  }

  public func refreshToken() async -> String? {
    DemoUserSeed.refreshToken
  }

  public func cachedUser() async -> User? {
    DemoUserSeed.currentUser
  }

  public func clear() async {}
}
