import Foundation
import SwiftUI

private struct CoachNowEnvironmentKey: EnvironmentKey {
  static let defaultValue = Date.distantPast
}

private struct CoachFullScreenRegistryKey: EnvironmentKey {
  static let defaultValue = CoachFullScreenDestinationRegistration { _, _ in }
}

struct CoachFullScreenDestinationRegistration: Sendable {
  let setActive: @MainActor @Sendable (UUID, Bool) -> Void

  init(setActive: @escaping @MainActor @Sendable (UUID, Bool) -> Void) {
    self.setActive = setActive
  }
}

extension EnvironmentValues {
  var coachNow: Date {
    get { self[CoachNowEnvironmentKey.self] }
    set { self[CoachNowEnvironmentKey.self] = newValue }
  }

  var coachFullScreenDestinationRegistration: CoachFullScreenDestinationRegistration {
    get { self[CoachFullScreenRegistryKey.self] }
    set { self[CoachFullScreenRegistryKey.self] = newValue }
  }
}

extension View {
  func coachFullScreenDestination() -> some View {
    modifier(CoachFullScreenDestinationModifier())
  }
}

private struct CoachFullScreenDestinationModifier: ViewModifier {
  @Environment(\.coachFullScreenDestinationRegistration) private var registration
  @State private var destinationID = UUID()

  func body(content: Content) -> some View {
    content
      .onAppear {
        registration.setActive(destinationID, true)
      }
      .onDisappear {
        registration.setActive(destinationID, false)
      }
  }
}
