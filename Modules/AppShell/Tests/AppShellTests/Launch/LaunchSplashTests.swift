import Foundation
import Testing

@testable import AppShell

// Spec 099 phase table: (animationFinished, firstScreenReady, reduceMotion, exitFinished) -> phase.
@Test(arguments: [
  (false, false, false, false, LaunchSplashPhase.playing),
  // Ready early: the entrance still plays to the end.
  (false, true, false, false, .playing),
  (true, false, false, false, .loading),
  (true, true, false, false, .exiting),
  (true, true, false, true, .removed),
  // Reduce Motion skips the entrance.
  (false, false, true, false, .loading),
  (false, true, true, false, .exiting),
  (false, true, true, true, .removed),
])
func launchSplashPhaseTable(
  animationFinished: Bool, firstScreenReady: Bool, reduceMotion: Bool, exitFinished: Bool,
  expected: LaunchSplashPhase
) {
  #expect(
    LaunchSplashPhase.resolve(
      animationFinished: animationFinished,
      firstScreenReady: firstScreenReady,
      reduceMotion: reduceMotion,
      exitFinished: exitFinished
    ) == expected
  )
}

@Test
func launchSplashStartsEmptyAndResolvesByTheEndOfTheEntrance() {
  let first = LaunchSplashTimeline.frame(at: 0)
  #expect(first.logoOpacity == 0)
  #expect(first.taglineOpacity == 0)
  #expect(first.pillOpacity == 0)
  #expect(first.trackAlpha == 0)
  #expect(abs(first.warmTopAlpha - 0.10) < 1e-9)
  #expect(abs(first.warmBottomAlpha - 0.18) < 1e-9)

  let last = LaunchSplashTimeline.frame(at: LaunchSplashTimeline.entranceDuration)
  #expect(abs(last.logoOpacity - 1) < 1e-6)
  #expect(abs(last.logoScale - 1) < 1e-6)
  #expect(abs(last.logoOffsetY) < 1e-6)
  #expect(abs(last.taglineOpacity - 1) < 1e-6)
  #expect(abs(last.taglineTrackingEm - -0.012) < 1e-6)
  #expect(abs(last.pillOpacity - 1) < 1e-6)
  #expect(abs(last.pillProgress - 1) < 1e-6)
  #expect(abs(last.trackAlpha - 0.085) < 1e-6)
}

@Test
func launchSplashKeyMomentsMatchTheReference() {
  // Logo lands at frame 19 of 30; the slogan resolves at frame 25.
  #expect(abs(LaunchSplashTimeline.frame(at: 19.0 / 30).logoOpacity - 1) < 1e-6)
  #expect(LaunchSplashTimeline.frame(at: 0.3).logoOpacity < 1)
  #expect(LaunchSplashTimeline.frame(at: 7.0 / 30).taglineOpacity == 0)
  #expect(abs(LaunchSplashTimeline.frame(at: 25.0 / 30).taglineOpacity - 1) < 1e-6)
  // The loader shows up one frame after 0.4 s.
  #expect(LaunchSplashTimeline.frame(at: 0.4).pillOpacity == 0)
  #expect(LaunchSplashTimeline.frame(at: 0.6).pillOpacity > 0)
}

@Test
func launchSplashLoaderOnlyEverTravelsLeftToRight() {
  // While it waits past the entrance, the pill may only move right while it is
  // visible; it returns to the left end only when fully faded out.
  var previous = LaunchSplashTimeline.frame(at: LaunchSplashTimeline.loaderStart)
  var sawRestart = false
  var time = LaunchSplashTimeline.loaderStart
  while time < 6 {
    time += 1.0 / 120
    let frame = LaunchSplashTimeline.frame(at: time)
    if frame.pillProgress < previous.pillProgress - 1e-9 {
      sawRestart = true
      #expect(previous.pillOpacity < 0.05)
      #expect(frame.pillOpacity < 0.05)
    }
    previous = frame
  }
  #expect(sawRestart)
}

@Test
func launchSplashLoaderIsVisibleInEveryLoopCycle() {
  let held = LaunchSplashTimeline.entranceDuration + LaunchSplashTimeline.loopFadeOut
  for cycle in 0..<3 {
    let middle = held + Double(cycle) * LaunchSplashTimeline.loopPeriod + 0.4
    #expect(abs(LaunchSplashTimeline.frame(at: middle).pillOpacity - 1) < 1e-6)
  }
}

@MainActor
@Test
func sessionReportsBootstrapSettledOnlyAfterRestoreFinishes() async {
  let session = Session(auth: InMemoryAuthRepository(), tokenStore: InMemoryTokenStore())
  #expect(!session.hasBootstrapped)

  await session.bootstrap()

  #expect(session.hasBootstrapped)
  #expect(session.state == .anonymous)
}
