import DesignSystem
import SwiftUI

struct TrainingFlowSnapshot: Equatable {
  let dayID: UUID?
  let completed: [UUID]
}

struct TrainingCompletionDock: View {
  let onComplete: () -> Void

  var body: some View {
    HoldToCompleteButton(action: onComplete)
      .padding(.horizontal, MeetPRSpacing.pageHorizontal)
      .padding(.vertical, MeetPRSpacing.space3)
      .background(Color.MeetPR.bgBase)
      .overlay(alignment: .top) {
        Rectangle().fill(Color.MeetPR.borderSubtle).frame(height: 1)
      }
      .accessibilityIdentifier("training.completionDock")
  }
}

/// Animate feedback locally, never the scroll-position/layout transaction.
struct TrainingFlowFeedback: ViewModifier {
  let trigger: UUID?
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var opacity = 1.0
  @State private var consumedTrigger: UUID?

  func body(content: Content) -> some View {
    content.opacity(opacity)
      .task(id: trigger) {
        guard let trigger else {
          consumedTrigger = nil
          opacity = 1
          return
        }
        guard consumedTrigger != trigger, !reduceMotion else {
          opacity = 1
          return
        }
        consumedTrigger = trigger
        opacity = 0.4
        await Task.yield()
        guard !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: 0.2)) { opacity = 1 }
      }
  }
}

/// Tracks user-driven scrolling, including deceleration, without replacing the ScrollView delegate.
struct TrainingScrollInteraction: ViewModifier {
  @Binding var isScrolling: Bool
  @Binding var keyboardVisible: Bool

  func body(content: Content) -> some View {
    Group {
      if #available(iOS 18.0, macOS 15.0, *) {
        content.onScrollPhaseChange { _, phase in
          isScrolling = phase == .tracking || phase == .interacting || phase == .decelerating
        }
      } else {
        content.overlay {
          TrainingLegacyScrollObserver(isScrolling: $isScrolling)
            .allowsHitTesting(false)
        }
      }
    }
    #if os(iOS)
      .onReceive(
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
      ) { _ in
        keyboardVisible = true
      }
      .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardDidHideNotification))
      { _ in
        keyboardVisible = false
      }
    #endif
  }
}

#if os(iOS)
  /// iOS 17 has no scroll-phase API. Read the enclosing scroll view's tracking flags;
  /// never replace its delegate or gesture recognizers.
  private struct TrainingLegacyScrollObserver: UIViewRepresentable {
    @Binding var isScrolling: Bool

    func makeUIView(context: Context) -> UIView {
      let view = UIView()
      context.coordinator.start(view: view)
      return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(isScrolling: $isScrolling) }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
      coordinator.task?.cancel()
    }

    @MainActor final class Coordinator {
      var task: Task<Void, Never>?
      let isScrolling: Binding<Bool>

      init(isScrolling: Binding<Bool>) { self.isScrolling = isScrolling }

      func start(view: UIView) {
        task = Task { @MainActor [weak view, weak self] in
          while !Task.isCancelled {
            guard let view, let self else { return }
            let scroll = Self.scrollView(in: view.superview)
            let active = scroll.map { $0.isTracking || $0.isDragging || $0.isDecelerating } ?? false
            if isScrolling.wrappedValue != active { isScrolling.wrappedValue = active }
            do { try await Task.sleep(for: .milliseconds(50)) } catch { return }
          }
        }
      }

      private static func scrollView(in view: UIView?) -> UIScrollView? {
        guard let view else { return nil }
        if let scroll = view as? UIScrollView { return scroll }
        if let scroll = view.subviews.compactMap({ $0 as? UIScrollView }).first { return scroll }
        return scrollView(in: view.superview)
      }
    }
  }
#else
  private struct TrainingLegacyScrollObserver: View {
    @Binding var isScrolling: Bool
    var body: some View { Color.clear }
  }
#endif

/// Recording rows move between sections. Eager layout resolves their target frames
/// while a full-screen set editor is dismissing; other routes retain the old lazy layout.
struct TrainingContentStack<Content: View>: View {
  let recording: Bool
  @ViewBuilder let content: Content

  var body: some View {
    if recording {
      VStack(alignment: .leading, spacing: MeetPRSpacing.point13) { content }
    } else {
      LazyVStack(alignment: .leading, spacing: MeetPRSpacing.point13) { content }
    }
  }
}
