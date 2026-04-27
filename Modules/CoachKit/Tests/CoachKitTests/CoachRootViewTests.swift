import Testing

@testable import CoachKit

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func coachRootViewInitializes() {
  _ = CoachRootView()
}
