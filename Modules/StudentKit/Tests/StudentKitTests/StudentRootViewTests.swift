import Testing

@testable import StudentKit

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func studentRootViewInitializes() {
  _ = StudentRootView()
}
