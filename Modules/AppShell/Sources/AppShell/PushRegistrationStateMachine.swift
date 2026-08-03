import Foundation

enum PushAuthorizationState: Equatable, Sendable {
  case notDetermined
  case allowed
  case denied
}

struct PushRegistrationKey: Equatable, Hashable, Sendable {
  let sessionID: UInt
  let token: String
}

enum PushRegistrationAction: Equatable, Sendable {
  case requestAuthorization
  case registerForRemoteNotifications
  case upload(PushRegistrationKey)
}

struct PushRegistrationStateMachine: Sendable {
  private(set) var activeSessionID: UInt?
  private(set) var latestToken: String?
  private(set) var lastUploadedKey: PushRegistrationKey?
  private var nextSessionID: UInt = 0
  private var authorizationRequestInFlight = false
  private var requestedRemoteRegistration = false
  private var uploadsInFlight: Set<PushRegistrationKey> = []

  mutating func beginAuthenticatedSession() -> Bool {
    guard activeSessionID == nil else { return false }
    nextSessionID &+= 1
    activeSessionID = nextSessionID
    authorizationRequestInFlight = false
    requestedRemoteRegistration = false
    uploadsInFlight.removeAll()
    return true
  }

  mutating func endAuthenticatedSession() {
    activeSessionID = nil
    authorizationRequestInFlight = false
    requestedRemoteRegistration = false
    uploadsInFlight.removeAll()
  }

  mutating func actionsForActivation(
    authorization: PushAuthorizationState
  ) -> [PushRegistrationAction] {
    guard activeSessionID != nil else { return [] }
    switch authorization {
    case .notDetermined:
      guard !authorizationRequestInFlight else { return [] }
      authorizationRequestInFlight = true
      return [.requestAuthorization]
    case .allowed:
      return allowedActions()
    case .denied:
      return []
    }
  }

  mutating func authorizationResolved(granted: Bool) -> [PushRegistrationAction] {
    authorizationRequestInFlight = false
    guard granted else { return [] }
    return allowedActions()
  }

  mutating func authorizationRequestFailed() {
    authorizationRequestInFlight = false
  }

  mutating func remoteRegistrationFailed() {
    requestedRemoteRegistration = false
  }

  mutating func receivedDeviceToken(_ token: String) -> [PushRegistrationAction] {
    latestToken = token
    guard let key = currentRegistrationKey else { return [] }
    return uploadActionIfNeeded(for: key)
  }

  mutating func uploadFinished(_ key: PushRegistrationKey, succeeded: Bool) {
    uploadsInFlight.remove(key)
    guard succeeded, key.sessionID == activeSessionID else { return }
    lastUploadedKey = key
  }

  private var currentRegistrationKey: PushRegistrationKey? {
    guard let activeSessionID, let latestToken else { return nil }
    return PushRegistrationKey(sessionID: activeSessionID, token: latestToken)
  }

  private mutating func allowedActions() -> [PushRegistrationAction] {
    var actions: [PushRegistrationAction] = []
    if !requestedRemoteRegistration {
      requestedRemoteRegistration = true
      actions.append(.registerForRemoteNotifications)
    }
    if let key = currentRegistrationKey {
      actions.append(contentsOf: uploadActionIfNeeded(for: key))
    }
    return actions
  }

  private mutating func uploadActionIfNeeded(
    for key: PushRegistrationKey
  ) -> [PushRegistrationAction] {
    guard lastUploadedKey != key, !uploadsInFlight.contains(key) else { return [] }
    uploadsInFlight.insert(key)
    return [.upload(key)]
  }
}

public enum DeviceTokenHex {
  public static func string(from data: Data) -> String {
    data.map { String($0, radix: 16).leftPadding(toLength: 2, withPad: "0") }.joined()
  }
}

extension String {
  fileprivate func leftPadding(toLength: Int, withPad character: Character) -> String {
    guard count < toLength else { return self }
    return String(repeating: character, count: toLength - count) + self
  }
}
