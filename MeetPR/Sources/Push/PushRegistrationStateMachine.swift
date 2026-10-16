#if !DEMO_MODE
  import Foundation

  enum PushAuthorizationState: Equatable, Sendable {
    case notDetermined
    case denied
    case authorized
  }

  struct PushRegistrationStateMachine: Sendable {
    enum Action: Equatable, Sendable {
      case requestAuthorization
      case registerForRemoteNotifications
      case uploadToken(String)
    }

    private(set) var coachID: UUID?
    private(set) var deviceToken: String?
    private var isRequestingAuthorization = false

    mutating func activate(
      coachID: UUID,
      authorization: PushAuthorizationState,
      hasRequestedAuthorization: Bool
    ) -> [Action] {
      self.coachID = coachID

      switch authorization {
      case .notDetermined:
        guard !hasRequestedAuthorization, !isRequestingAuthorization else {
          return []
        }
        isRequestingAuthorization = true
        return [.requestAuthorization]
      case .denied:
        isRequestingAuthorization = false
        return []
      case .authorized:
        isRequestingAuthorization = false
        return registrationActions()
      }
    }

    mutating func completeAuthorization(granted: Bool) -> [Action] {
      isRequestingAuthorization = false
      guard granted, coachID != nil else { return [] }
      return registrationActions()
    }

    mutating func failAuthorizationRequest() {
      isRequestingAuthorization = false
    }

    mutating func receiveDeviceToken(_ token: String) -> [Action] {
      deviceToken = token
      guard coachID != nil else { return [] }
      return [.uploadToken(token)]
    }

    mutating func deactivate() {
      coachID = nil
      isRequestingAuthorization = false
    }

    private func registrationActions() -> [Action] {
      var actions: [Action] = [.registerForRemoteNotifications]
      if let deviceToken {
        actions.append(.uploadToken(deviceToken))
      }
      return actions
    }
  }
#endif
