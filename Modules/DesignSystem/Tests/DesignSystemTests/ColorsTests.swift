import SwiftUI
import Testing

@testable import DesignSystem

@available(iOS 17.0, macOS 14.0, *)
@Test func primaryColorIsNotClear() {
  #expect(Color.meetprPrimary != .clear)
}
