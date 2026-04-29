import CoreModels
import Foundation
import Security

public protocol TokenStoring: Sendable {
  func save(access: String, refresh: String) async
  func saveUser(_ user: User) async
  func accessToken() async -> String?
  func refreshToken() async -> String?
  func cachedUser() async -> User?
  func clear() async
}

public actor TokenStore: TokenStoring {
  private enum Account {
    static let accessToken = "accessToken"
    static let cachedUser = "cachedUser"
    static let refreshToken = "refreshToken"
  }

  private let serviceName: String

  public init(serviceName: String = "MeetPR") {
    self.serviceName = serviceName
  }

  public func save(access: String, refresh: String) async {
    save(Data(access.utf8), account: Account.accessToken)
    save(Data(refresh.utf8), account: Account.refreshToken)
  }

  public func saveUser(_ user: User) async {
    guard let data = try? MeetPRCodec.encoder.encode(user) else {
      return
    }
    save(data, account: Account.cachedUser)
  }

  public func accessToken() async -> String? {
    string(account: Account.accessToken)
  }

  public func refreshToken() async -> String? {
    string(account: Account.refreshToken)
  }

  public func cachedUser() async -> User? {
    guard let data = data(account: Account.cachedUser) else {
      return nil
    }
    return try? MeetPRCodec.decoder.decode(User.self, from: data)
  }

  public func clear() async {
    delete(account: Account.accessToken)
    delete(account: Account.refreshToken)
    delete(account: Account.cachedUser)
  }

  private func string(account: String) -> String? {
    guard let data = data(account: account) else {
      return nil
    }
    return String(data: data, encoding: .utf8)
  }

  private func save(_ data: Data, account: String) {
    delete(account: account)
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
      kSecAttrAccount as String: account,
      kSecAttrService as String: serviceName,
      kSecValueData as String: data,
    ]
    _ = SecItemAdd(query as CFDictionary, nil)
  }

  private func data(account: String) -> Data? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrAccount as String: account,
      kSecAttrService as String: serviceName,
      kSecMatchLimit as String: kSecMatchLimitOne,
      kSecReturnData as String: true,
    ]

    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    guard status == errSecSuccess else {
      return nil
    }
    return item as? Data
  }

  private func delete(account: String) {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrAccount as String: account,
      kSecAttrService as String: serviceName,
    ]
    _ = SecItemDelete(query as CFDictionary)
  }
}

public actor InMemoryTokenStore: TokenStoring {
  private var access: String?
  private var refresh: String?
  private var user: User?

  public init(access: String? = nil, refresh: String? = nil, user: User? = nil) {
    self.access = access
    self.refresh = refresh
    self.user = user
  }

  public func save(access: String, refresh: String) async {
    self.access = access
    self.refresh = refresh
  }

  public func saveUser(_ user: User) async {
    self.user = user
  }

  public func accessToken() async -> String? {
    access
  }

  public func refreshToken() async -> String? {
    refresh
  }

  public func cachedUser() async -> User? {
    user
  }

  public func clear() async {
    access = nil
    refresh = nil
    user = nil
  }
}
