import DesignSystem
import SwiftUI

#if os(iOS)
  import UIKit
#endif

enum CoachTab: CaseIterable, Hashable {
  case today
  case messages
  case students
  case profile
}

/// Stable per-tab presentation, kept structurally identical to the student shell.
///
/// Keep the shell and host in this dedicated file rather than recreating a
/// file-private host inside `CoachRootView`: the stable representable type keeps
/// hit-testing and accessibility exposure synchronized through root data refreshes.
struct CoachTabShellPresentation: Equatable {
  struct Layer: Equatable, Identifiable {
    let id: CoachTab
    let opacity: Double
    let allowsHitTesting: Bool
    let isAccessibilityHidden: Bool
    let isEnabled: Bool
    let zIndex: Double
  }

  let selection: CoachTab

  var layers: [Layer] {
    CoachTab.allCases.map(layer(for:))
  }

  func layer(for tab: CoachTab) -> Layer {
    let isSelected = selection == tab
    return Layer(
      id: tab,
      opacity: isSelected ? 1 : 0,
      allowsHitTesting: isSelected,
      isAccessibilityHidden: !isSelected,
      isEnabled: isSelected,
      zIndex: isSelected ? 1 : 0
    )
  }
}

extension View {
  @ViewBuilder
  func coachTabLayer(
    _ layer: CoachTabShellPresentation.Layer,
    store: CoachTabHostStore
  ) -> some View {
    #if os(iOS)
      CoachTabAccessibilityHost(
        id: layer.id,
        rootView: self.buttonStyle(PressScaleButtonStyle()),
        store: store,
        accessibilityElementsHidden: layer.isAccessibilityHidden
      )
      .disabled(!layer.isEnabled)
      .opacity(layer.opacity)
      .allowsHitTesting(layer.allowsHitTesting)
      .id(layer.id)
      .zIndex(layer.zIndex)
    #else
      self
        .disabled(!layer.isEnabled)
        .opacity(layer.opacity)
        .allowsHitTesting(layer.allowsHitTesting)
        .accessibilityHidden(layer.isAccessibilityHidden)
        .id(layer.id)
        .zIndex(layer.zIndex)
    #endif
  }

}

@MainActor
final class CoachTabHostStore {
  #if os(iOS)
    private var controllers: [CoachTab: UIViewController] = [:]

    func hostingController<Content: View>(
      for id: CoachTab,
      rootView: Content
    ) -> UIHostingController<Content> {
      if let existing = controllers[id] as? UIHostingController<Content> {
        existing.rootView = rootView
        return existing
      }
      let controller = UIHostingController(rootView: rootView)
      controllers[id] = controller
      return controller
    }
  #endif
}

#if os(iOS)
  // Shared-infrastructure follow-up: extract this host with StudentTabAccessibilityHost.
  private struct CoachTabAccessibilityHost<Content: View>: UIViewControllerRepresentable {
    let id: CoachTab
    let rootView: Content
    let store: CoachTabHostStore
    let accessibilityElementsHidden: Bool

    func makeCoordinator() -> Coordinator {
      Coordinator(
        hostingController: store.hostingController(for: id, rootView: rootView)
      )
    }

    func makeUIViewController(context: Context) -> UIViewController {
      let container = UIViewController()
      let hostingController = context.coordinator.hostingController
      if accessibilityElementsHidden {
        detach(hostingController)
      } else {
        attach(hostingController, to: container)
      }
      updateAccessibility(on: container, hostingController: hostingController)
      return container
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
      context.coordinator.hostingController.rootView = rootView
      if accessibilityElementsHidden {
        detach(context.coordinator.hostingController)
      } else {
        attach(context.coordinator.hostingController, to: uiViewController)
      }
      updateAccessibility(
        on: uiViewController,
        hostingController: context.coordinator.hostingController
      )
    }

    static func dismantleUIViewController(
      _ uiViewController: UIViewController,
      coordinator: Coordinator
    ) {
      if coordinator.hostingController.parent === uiViewController {
        coordinator.hostingController.willMove(toParent: nil)
        coordinator.hostingController.view.removeFromSuperview()
        coordinator.hostingController.removeFromParent()
      }
    }

    private func attach(
      _ hostingController: UIHostingController<Content>,
      to container: UIViewController
    ) {
      guard hostingController.parent !== container else { return }
      detach(hostingController)
      container.addChild(hostingController)
      container.view.addSubview(hostingController.view)
      hostingController.view.translatesAutoresizingMaskIntoConstraints = false
      NSLayoutConstraint.activate([
        hostingController.view.leadingAnchor.constraint(equalTo: container.view.leadingAnchor),
        hostingController.view.trailingAnchor.constraint(equalTo: container.view.trailingAnchor),
        hostingController.view.topAnchor.constraint(equalTo: container.view.topAnchor),
        hostingController.view.bottomAnchor.constraint(equalTo: container.view.bottomAnchor),
      ])
      hostingController.didMove(toParent: container)
    }

    private func detach(_ hostingController: UIHostingController<Content>) {
      guard hostingController.parent != nil else { return }
      hostingController.willMove(toParent: nil)
      hostingController.view.removeFromSuperview()
      hostingController.removeFromParent()
    }

    private func updateAccessibility(
      on container: UIViewController,
      hostingController: UIHostingController<Content>
    ) {
      container.view.isHidden = accessibilityElementsHidden
      container.view.accessibilityElementsHidden = accessibilityElementsHidden
      hostingController.view.isHidden = accessibilityElementsHidden
      hostingController.view.accessibilityElementsHidden = accessibilityElementsHidden
      hostingController.view.isAccessibilityElement = false
    }

    @MainActor
    final class Coordinator {
      let hostingController: UIHostingController<Content>

      init(hostingController: UIHostingController<Content>) {
        self.hostingController = hostingController
      }
    }
  }
#endif
