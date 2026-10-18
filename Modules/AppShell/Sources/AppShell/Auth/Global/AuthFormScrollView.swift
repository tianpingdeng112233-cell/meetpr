import SwiftUI

/// Keeps the focused auth field in view as the keyboard reduces the viewport.
@available(iOS 17.0, macOS 14.0, *)
struct AuthFormScrollView<Content: View>: View {
  @FocusedValue(\.authScrollTarget) private var focusedTarget
  var fillsViewport = false
  @ViewBuilder let content: Content

  var body: some View {
    GeometryReader { geometry in
      ScrollViewReader { scroll in
        ScrollView {
          content
            .frame(
              maxWidth: .infinity,
              minHeight: fillsViewport ? geometry.size.height : nil,
              alignment: .top
            )
        }
        .scrollBounceBehavior(.always)
        .scrollDismissesKeyboard(.interactively)
        .onChange(of: focusedTarget) { _, target in
          if let target { scroll.scrollTo(target, anchor: .center) }
        }
        .onChange(of: geometry.size.height) { previous, current in
          // Focus can arrive before the keyboard has resized the scroll view.
          // Reposition after shrinking, but leave manual scrolling/dismissal alone.
          if current < previous, let focusedTarget {
            scroll.scrollTo(focusedTarget, anchor: .center)
          }
        }
      }
    }
  }
}

private struct AuthScrollTargetKey: FocusedValueKey {
  typealias Value = String
}

extension FocusedValues {
  fileprivate var authScrollTarget: String? {
    get { self[AuthScrollTargetKey.self] }
    set { self[AuthScrollTargetKey.self] = newValue }
  }
}

extension View {
  /// Publishing on the field container also covers secure/plain password toggles.
  func authScrollTarget(_ identifier: String) -> some View {
    id(identifier)
      .focusedValue(\.authScrollTarget, identifier)
      .accessibilityIdentifier(identifier)
  }
}
