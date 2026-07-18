#if !DEMO_MODE
  import AppShell
  import UIKit
  import UserNotifications

  @MainActor
  final class MeetPRAppDelegate: NSObject, UIApplicationDelegate,
    @preconcurrency UNUserNotificationCenterDelegate
  {
    typealias RouteHandler = @MainActor @Sendable (AppRoute) -> Void
    typealias DeviceTokenHandler = @MainActor @Sendable (Data) -> Void

    private var routeHandler: RouteHandler?
    private var deviceTokenHandler: DeviceTokenHandler?
    private var pendingRoute: AppRoute?

    func configure(
      routeHandler: @escaping RouteHandler,
      deviceTokenHandler: @escaping DeviceTokenHandler
    ) {
      self.routeHandler = routeHandler
      self.deviceTokenHandler = deviceTokenHandler

      if let pendingRoute {
        routeHandler(pendingRoute)
        self.pendingRoute = nil
      }
    }

    func application(
      _ application: UIApplication,
      didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
      UNUserNotificationCenter.current().delegate = self
      return true
    }

    func application(
      _ application: UIApplication,
      didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
      deviceTokenHandler?(deviceToken)
    }

    func application(
      _ application: UIApplication,
      didFailToRegisterForRemoteNotificationsWithError error: any Error
    ) {
      // Registration is best-effort. A later activation or launch retries it.
    }

    func userNotificationCenter(
      _ center: UNUserNotificationCenter,
      willPresent notification: UNNotification,
      withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
      completionHandler([.badge])
    }

    func userNotificationCenter(
      _ center: UNUserNotificationCenter,
      didReceive response: UNNotificationResponse,
      withCompletionHandler completionHandler: @escaping () -> Void
    ) {
      let content = response.notification.request.content
      didReceiveNotification(
        categoryIdentifier: content.categoryIdentifier,
        userInfo: content.userInfo
      )
      completionHandler()
    }

    func didReceiveNotification(
      categoryIdentifier: String,
      userInfo: [AnyHashable: Any]
    ) {
      guard
        let route = PushNotificationRouteParser.route(
          categoryIdentifier: categoryIdentifier,
          userInfo: userInfo
        )
      else { return }

      if let routeHandler {
        routeHandler(route)
      } else {
        pendingRoute = route
      }
    }
  }
#endif
