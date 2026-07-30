import Testing

@testable import CoachKit

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func coachRootViewInitializes() {
  _ = CoachRootView()
}

@Test func exactlyOneCoachTabLayerIsInteractiveAndAccessible() {
  for selection in CoachTab.allCases {
    let layers = CoachTabShellPresentation(selection: selection).layers
    let accessible = layers.filter { !$0.isAccessibilityHidden }

    #expect(accessible.map(\.id) == [selection])
    #expect(layers.filter(\.allowsHitTesting).map(\.id) == [selection])
    #expect(layers.filter(\.isEnabled).map(\.id) == [selection])
    #expect(layers.first(where: { $0.id == selection })?.zIndex == 1)
  }
}
