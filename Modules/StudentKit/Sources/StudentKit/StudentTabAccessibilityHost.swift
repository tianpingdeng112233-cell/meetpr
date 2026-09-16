import DesignSystem
import SwiftUI
#if os(iOS)
  import UIKit
#endif

extension View {
  @ViewBuilder
  func studentTabLayer(
    _ layer: StudentTabShellPresentation.Layer,
    store: StudentTabHostStore
  ) -> some View {
    #if os(iOS)
      StudentTabAccessibilityHost(
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
final class StudentTabHostStore {
  #if os(iOS)
    private var controllers: [StudentTab: UIViewController] = [:]

    func hostingController<Content: View>(
      for id: StudentTab,
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
  private struct StudentTabAccessibilityHost<Content: View>: UIViewControllerRepresentable {
    let id: StudentTab
    let rootView: Content
    let store: StudentTabHostStore
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
