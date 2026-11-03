import CoreModels
import StudentKit
import SwiftUI

@available(iOS 17.0, macOS 14.0, *)
extension RootView {
  var studentNotificationPermissionActions: StudentNotificationPermissionActions {
    StudentNotificationPermissionActions(
      canRequest: { await pushRegistrar?.canRequestNotificationPermission() ?? false },
      request: { await pushRegistrar?.requestNotificationPermission() }
    )
  }

  static func isAuthenticated(_ state: Session.State) -> Bool {
    if case .authenticated = state { return true }
    return false
  }

  var pushRouteBinding: Binding<PushRouteIntent?> {
    Binding(
      get: { pushRegistrar?.pendingRoute },
      set: { route in
        guard route == nil, let pendingRoute = pushRegistrar?.pendingRoute else { return }
        pushRegistrar?.consumePendingRoute(pendingRoute)
      }
    )
  }
}
