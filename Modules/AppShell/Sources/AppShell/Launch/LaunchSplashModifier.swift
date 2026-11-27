import DesignSystem
import SwiftUI

/// Cold-start splash (spec 099). Plays once per process on top of the app while
/// session restore and the first screen load underneath, then fades out.
@available(iOS 17.0, macOS 14.0, *)
struct LaunchSplashModifier: ViewModifier {
  @Environment(Session.self) private var session
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  @State private var clock = LaunchSplashClock()
  @State private var isBlocked = false
  @State private var animationFinished = false
  @State private var firstScreenReady = false
  @State private var exitFinished = false

  /// A ready reading must hold this long, so the one frame between two
  /// consecutive loading gates cannot dismiss the splash.
  private static let readySettle: Duration = .milliseconds(80)

  private var phase: LaunchSplashPhase {
    .resolve(
      animationFinished: animationFinished,
      firstScreenReady: firstScreenReady,
      reduceMotion: reduceMotion,
      exitFinished: exitFinished
    )
  }

  func body(content: Content) -> some View {
    // A ZStack, not an overlay: an overlay would shrink the splash to the size
    // of whatever is underneath, and the restore placeholder is a bare spinner.
    ZStack {
      content
        .onPreferenceChange(LaunchBlockingPreferenceKey.self) { blocked in
          Task { @MainActor in isBlocked = blocked }
        }
      if phase != .removed {
        splash
          .opacity(phase == .exiting ? 0 : 1)
          .animation(.easeInOut(duration: LaunchSplashTimeline.exitDuration), value: phase)
          .transition(.identity)
      }
    }
    .task {
      // The entrance is over once it has actually been drawn to the end, not
      // 1.2 s after launch: a slow cold start must not swallow it.
      while clock.elapsed < LaunchSplashTimeline.entranceDuration {
        try? await Task.sleep(for: .milliseconds(16))
        if Task.isCancelled { return }
      }
      animationFinished = true
    }
    .task(id: ReadyInput(bootstrapped: session.hasBootstrapped, blocked: isBlocked)) {
      guard !firstScreenReady, session.hasBootstrapped, !isBlocked else { return }
      try? await Task.sleep(for: Self.readySettle)
      guard !Task.isCancelled else { return }
      firstScreenReady = true
    }
    .task(id: phase) {
      guard phase == .exiting else { return }
      try? await Task.sleep(for: .seconds(LaunchSplashTimeline.exitDuration))
      exitFinished = true
    }
  }

  private var splash: some View {
    TimelineView(.animation) { context in
      let elapsed = clock.advance(to: context.date)
      // Reduce Motion: open on the last frame; only the loader keeps moving.
      let time = reduceMotion ? LaunchSplashTimeline.entranceDuration + elapsed : elapsed
      LaunchSplashView(frame: LaunchSplashTimeline.frame(at: time))
    }
  }

  private struct ReadyInput: Equatable {
    let bootstrapped: Bool
    let blocked: Bool
  }
}

/// Animation time for the splash: starts at the first frame that is actually
/// drawn and never jumps ahead by more than `maxStep`, so a stalled main
/// thread pauses the entrance instead of skipping it.
@MainActor
final class LaunchSplashClock {
  static let maxStep = 0.05

  private(set) var elapsed = 0.0
  private var lastFrame: Date?

  @discardableResult
  func advance(to date: Date) -> Double {
    if let lastFrame {
      elapsed += min(Self.maxStep, max(0, date.timeIntervalSince(lastFrame)))
    }
    lastFrame = date
    return elapsed
  }
}

extension View {
  /// Covers the app with the cold-start splash until the first screen is ready.
  /// Needs a `Session` in the environment.
  @available(iOS 17.0, macOS 14.0, *)
  public func launchSplash() -> some View {
    modifier(LaunchSplashModifier())
  }
}
