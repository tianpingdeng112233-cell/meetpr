import Testing

@testable import DesignSystem

@Suite("Design system demo")
@MainActor
struct DesignSystemDemoTests {
  @Test("demo catalog instantiates")
  func demoSmoke() {
    _ = DesignSystemDemo()
  }
}
