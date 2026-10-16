#if !DEMO_MODE
  import CoreModels
  import Foundation
  import UIKit
  import UserNotifications

  struct PushNotificationSystem: Sendable {
    let authorizationState: @MainActor @Sendable () async -> PushAuthorizationState
    let requestAuthorization: @MainActor @Sendable () async throws -> Bool
    let registerForRemoteNotifications: @MainActor @Sendable () -> Void

    static let live = PushNotificationSystem(
      authorizationState: {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
          return .notDetermined
        case .denied:
          return .denied
        case .authorized, .provisional, .ephemeral:
          return .authorized
        @unknown default:
          return .denied
        }
      },
      requestAuthorization: {
        try await UNUserNotificationCenter.current().requestAuthorization(
          options: [.alert, .sound, .badge])
      },
      registerForRemoteNotifications: {
        UIApplication.shared.registerForRemoteNotifications()
      }
    )
  }

  protocol PushAuthorizationPromptStoring: Sendable {
    func hasRequestedAuthorization(for accountID: UUID) async -> Bool
    func markAuthorizationRequested(for accountID: UUID) async
  }

  actor UserDefaultsPushAuthorizationPromptStore: PushAuthorizationPromptStoring {
    private let suiteName: String?

    init(suiteName: String? = nil) {
      self.suiteName = suiteName
    }

    func hasRequestedAuthorization(for accountID: UUID) -> Bool {
      defaults.bool(forKey: key(for: accountID))
    }

    func markAuthorizationRequested(for accountID: UUID) {
      defaults.set(true, forKey: key(for: accountID))
    }

    private var defaults: UserDefaults {
      suiteName.flatMap { UserDefaults(suiteName: $0) } ?? .standard
    }

    private func key(for accountID: UUID) -> String {
      "push.authorization-requested.\(accountID.uuidString.lowercased())"
    }
  }

  @MainActor
  final class PushRegistrationCoordinator {
    typealias TokenUploader = @MainActor @Sendable (String, UUID) async throws -> Void

    private struct UploadRequest: Equatable {
      let token: String
      let accountID: UUID
      let generation: UInt
    }

    private let notificationSystem: PushNotificationSystem
    private let promptStore: any PushAuthorizationPromptStoring
    private let uploadToken: TokenUploader
    private var stateMachine = PushRegistrationStateMachine()
    private var activeCoachID: UUID?
    private var activationGeneration: UInt = 0
    private var uploadTask: Task<Void, Never>?
    private var uploadRequest: UploadRequest?
    private var pendingUploadRequest: UploadRequest?

    init(
      notificationSystem: PushNotificationSystem = .live,
      promptStore: any PushAuthorizationPromptStoring = UserDefaultsPushAuthorizationPromptStore(),
      uploadToken: @escaping TokenUploader
    ) {
      self.notificationSystem = notificationSystem
      self.promptStore = promptStore
      self.uploadToken = uploadToken
    }

    func activate(for user: User) {
      guard user.role == .coach else {
        deactivate()
        return
      }

      if activeCoachID != user.id {
        invalidateActiveCoach()
        activeCoachID = user.id
      }

      let generation = activationGeneration
      Task { [weak self] in
        guard let self else { return }
        await runActivation(for: user, generation: generation)
      }
    }

    private func runActivation(for user: User, generation: UInt) async {
      guard isCurrent(generation: generation, coachID: user.id) else { return }

      let authorization = await notificationSystem.authorizationState()
      guard isCurrent(generation: generation, coachID: user.id) else { return }
      let hasRequested = await promptStore.hasRequestedAuthorization(for: user.id)
      guard isCurrent(generation: generation, coachID: user.id) else { return }
      let actions = stateMachine.activate(
        coachID: user.id,
        authorization: authorization,
        hasRequestedAuthorization: hasRequested
      )
      await perform(actions, accountID: user.id, generation: generation)
    }

    func deactivate() {
      invalidateActiveCoach()
    }

    func receiveDeviceToken(_ data: Data) {
      let token = DeviceTokenHexEncoder.string(from: data)
      performTokenActions(
        stateMachine.receiveDeviceToken(token),
        accountID: stateMachine.coachID,
        generation: activationGeneration
      )
    }

    private func perform(
      _ actions: [PushRegistrationStateMachine.Action],
      accountID: UUID?,
      generation: UInt
    ) async {
      for action in actions {
        guard isCurrent(generation: generation, coachID: accountID) else { return }
        switch action {
        case .requestAuthorization:
          await requestAuthorization(accountID: accountID, generation: generation)
        case .registerForRemoteNotifications:
          notificationSystem.registerForRemoteNotifications()
        case .uploadToken(let token):
          enqueueUpload(token: token, accountID: accountID, generation: generation)
        }
      }
    }

    private func performTokenActions(
      _ actions: [PushRegistrationStateMachine.Action],
      accountID: UUID?,
      generation: UInt
    ) {
      for action in actions {
        guard isCurrent(generation: generation, coachID: accountID) else { return }
        guard case .uploadToken(let token) = action else { continue }
        enqueueUpload(token: token, accountID: accountID, generation: generation)
      }
    }

    private func requestAuthorization(accountID: UUID?, generation: UInt) async {
      guard let accountID else {
        guard isCurrent(generation: generation, coachID: accountID) else { return }
        stateMachine.failAuthorizationRequest()
        return
      }

      do {
        let granted = try await notificationSystem.requestAuthorization()
        guard isCurrent(generation: generation, coachID: accountID) else { return }
        await promptStore.markAuthorizationRequested(for: accountID)
        guard isCurrent(generation: generation, coachID: accountID) else { return }
        await perform(
          stateMachine.completeAuthorization(granted: granted),
          accountID: accountID,
          generation: generation
        )
      } catch {
        guard isCurrent(generation: generation, coachID: accountID) else { return }
        // A transient system failure should be retried on the next activation
        // or launch. Do not persist the per-account prompt marker here.
        stateMachine.failAuthorizationRequest()
      }
    }

    private func enqueueUpload(token: String, accountID: UUID?, generation: UInt) {
      guard let accountID, isCurrent(generation: generation, coachID: accountID) else { return }
      let request = UploadRequest(token: token, accountID: accountID, generation: generation)
      guard uploadRequest != request, pendingUploadRequest != request else { return }
      pendingUploadRequest = request
      startNextUploadIfNeeded()
    }

    private func startNextUploadIfNeeded() {
      guard uploadTask == nil, let request = pendingUploadRequest else { return }
      pendingUploadRequest = nil
      uploadRequest = request
      let uploadToken = uploadToken
      uploadTask = Task { [weak self] in
        do {
          try await uploadToken(request.token, request.accountID)
        } catch {
          // Upload failures are lifecycle-only retries: the cached token is
          // retried on foreground activation or the next launch, never in a
          // bounded in-flight retry loop.
        }
        self?.finishUpload(request)
      }
    }

    private func finishUpload(_ request: UploadRequest) {
      guard uploadRequest == request else { return }
      uploadTask = nil
      uploadRequest = nil

      // Cancellation is cooperative. An old-account request can still reach
      // the backend, so every completion must cross the generation gate. If a
      // new coach is active, serialize a reassert after that stale write so the
      // backend's last-write-wins owner is the current account.
      if !isCurrent(generation: request.generation, coachID: request.accountID),
        let activeCoachID,
        let token = stateMachine.deviceToken
      {
        pendingUploadRequest = UploadRequest(
          token: token,
          accountID: activeCoachID,
          generation: activationGeneration
        )
      }

      startNextUploadIfNeeded()
    }

    private func invalidateActiveCoach() {
      activationGeneration &+= 1
      activeCoachID = nil
      stateMachine.deactivate()
      pendingUploadRequest = nil
      uploadTask?.cancel()
    }

    private func isCurrent(generation: UInt, coachID: UUID?) -> Bool {
      generation == activationGeneration && coachID == activeCoachID
    }
  }

  enum DeviceTokenHexEncoder {
    static func string(from data: Data) -> String {
      data.map { byte in
        let digits = String(byte, radix: 16, uppercase: false)
        return byte < 16 ? "0\(digits)" : digits
      }.joined()
    }
  }
#endif
