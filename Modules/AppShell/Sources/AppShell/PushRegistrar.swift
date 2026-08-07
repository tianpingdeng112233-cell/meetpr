// swiftlint:disable sorted_imports
import CoreModels
import Foundation
import Networking
import OSLog
import Observation

#if os(iOS)
  import UIKit
  import UserNotifications
#endif
// swiftlint:enable sorted_imports

@Observable
@MainActor
public final class PushRegistrar {
  public private(set) var pendingRoute: PushRouteIntent?

  @ObservationIgnored private let authorizationStatusProvider:
    @Sendable () async -> PushAuthorizationState
  @ObservationIgnored private let authorizationRequester: @Sendable () async throws -> Bool
  @ObservationIgnored private let remoteRegistration: @MainActor @Sendable () -> Void
  @ObservationIgnored private let accessTokenProvider: @Sendable () async throws -> String
  @ObservationIgnored private let tokenUploader: @Sendable (String, String) async throws -> Void
  @ObservationIgnored private var stateMachine = PushRegistrationStateMachine()
  @ObservationIgnored private var activationTask: Task<Void, Never>?
  /// Uploads are chained FIFO across sessions: a stale upload from a previous
  /// login always lands before the current session's, so the server's
  /// last-write token attribution is always the newest user. Cancelling the
  /// stale request would not achieve this — its server-side write could still
  /// land after the new session's upload.
  @ObservationIgnored private var uploadPipeline: Task<Void, Never>?

  private static let logger = Logger(
    subsystem: "com.meetpr.app.appshell",
    category: "push-registration"
  )

  init(
    authorizationStatusProvider: @escaping @Sendable () async -> PushAuthorizationState,
    authorizationRequester: @escaping @Sendable () async throws -> Bool,
    remoteRegistration: @escaping @MainActor @Sendable () -> Void,
    accessTokenProvider: @escaping @Sendable () async throws -> String,
    tokenUploader: @escaping @Sendable (String, String) async throws -> Void
  ) {
    self.authorizationStatusProvider = authorizationStatusProvider
    self.authorizationRequester = authorizationRequester
    self.remoteRegistration = remoteRegistration
    self.accessTokenProvider = accessTokenProvider
    self.tokenUploader = tokenUploader
  }

  public func authenticatedRootDidAppear() {
    guard stateMachine.beginAuthenticatedSession() else { return }
    scheduleActivation()
  }

  public func authenticatedSessionDidEnd() {
    activationTask?.cancel()
    activationTask = nil
    stateMachine.endAuthenticatedSession()
  }

  public func applicationDidBecomeActive() {
    guard stateMachine.activeSessionID != nil else { return }
    scheduleActivation()
  }

  public func receivedDeviceToken(_ hexToken: String) {
    perform(stateMachine.receivedDeviceToken(hexToken))
  }

  public func remoteRegistrationFailed(_ error: Error) {
    stateMachine.remoteRegistrationFailed()
    Self.logger.warning(
      "remote_notification_registration_failed \(String(describing: error), privacy: .public)"
    )
  }

  public func receiveNotificationPayload(_ payload: PushPayloadValues) {
    guard let route = PushPayloadParser.route(from: payload) else { return }
    pendingRoute = route
  }

  public func consumePendingRoute(_ route: PushRouteIntent) {
    guard pendingRoute == route else { return }
    pendingRoute = nil
  }

  private func scheduleActivation() {
    guard activationTask == nil else { return }
    activationTask = Task { @MainActor [weak self] in
      guard let self else { return }
      await activate()
      activationTask = nil
    }
  }

  private func activate() async {
    let authorization = await authorizationStatusProvider()
    perform(stateMachine.actionsForActivation(authorization: authorization))
  }

  private func perform(_ actions: [PushRegistrationAction]) {
    for action in actions {
      switch action {
      case .requestAuthorization:
        Task { @MainActor [weak self] in
          await self?.requestAuthorization()
        }
      case .registerForRemoteNotifications:
        remoteRegistration()
      case .upload(let key):
        enqueueUpload(key)
      }
    }
  }

  private func requestAuthorization() async {
    do {
      let granted = try await authorizationRequester()
      perform(stateMachine.authorizationResolved(granted: granted))
    } catch {
      stateMachine.authorizationRequestFailed()
      Self.logger.warning(
        "notification_authorization_request_failed \(String(describing: error), privacy: .public)"
      )
    }
  }

  private func enqueueUpload(_ key: PushRegistrationKey) {
    let previous = uploadPipeline
    uploadPipeline = Task { @MainActor [weak self] in
      await previous?.value
      await self?.upload(key)
    }
  }

  private func upload(_ key: PushRegistrationKey) async {
    do {
      let accessToken = try await accessTokenProvider()
      try await tokenUploader(key.token, accessToken)
      stateMachine.uploadFinished(key, succeeded: true)
    } catch {
      stateMachine.uploadFinished(key, succeeded: false)
      Self.logger.warning(
        "device_token_upload_failed \(String(describing: error), privacy: .public)"
      )
    }
  }
}

#if os(iOS)
  extension PushRegistrar {
    public convenience init(
      apiClient: APIClient,
      session: any SessionStateReader,
      notificationCenter: UNUserNotificationCenter = .current()
    ) {
      self.init(
        authorizationStatusProvider: {
          let settings = await notificationCenter.notificationSettings()
          switch settings.authorizationStatus {
          case .notDetermined:
            return .notDetermined
          case .authorized, .provisional, .ephemeral:
            return .allowed
          case .denied:
            return .denied
          @unknown default:
            return .denied
          }
        },
        authorizationRequester: {
          try await notificationCenter.requestAuthorization(options: [.alert, .sound, .badge])
        },
        remoteRegistration: {
          UIApplication.shared.registerForRemoteNotifications()
        },
        accessTokenProvider: {
          try await session.accessToken()
        },
        tokenUploader: { token, accessToken in
          try await apiClient.registerDeviceToken(token, accessToken: accessToken)
        }
      )
    }
  }

  @MainActor
  public final class PushNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    private weak var registrar: PushRegistrar?
    /// App-local notifications (e.g. upload-failure alerts, spec 069) route
    /// here first; returning true consumes the tap before push routing.
    private let localRouting: (@MainActor ([AnyHashable: Any]) -> Bool)?

    public init(
      registrar: PushRegistrar,
      localRouting: (@MainActor ([AnyHashable: Any]) -> Bool)? = nil
    ) {
      self.registrar = registrar
      self.localRouting = localRouting
    }

    public func userNotificationCenter(
      _ center: UNUserNotificationCenter,
      willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
      let kind = notification.request.content.userInfo["kind"] as? String
      switch PushForegroundPresentation.policy(for: kind) {
      case .suppress:
        return []
      case .bannerAndSound:
        return [.banner, .sound]
      }
    }

    public func userNotificationCenter(
      _ center: UNUserNotificationCenter,
      didReceive response: UNNotificationResponse
    ) async {
      let userInfo = response.notification.request.content.userInfo
      if localRouting?(userInfo) == true { return }
      registrar?.receiveNotificationPayload(Self.payloadValues(from: userInfo))
    }

    private static func payloadValues(from userInfo: [AnyHashable: Any]) -> PushPayloadValues {
      PushPayloadValues(
        kind: userInfo["kind"] as? String,
        conversationID: userInfo["conversation_id"] as? String,
        studentID: userInfo["student_id"] as? String,
        videoID: userInfo["video_id"] as? String,
        requestID: userInfo["request_id"] as? String,
        planID: userInfo["plan_id"] as? String
      )
    }
  }
#endif
