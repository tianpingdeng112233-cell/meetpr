/// Where the cold-start splash is in its life (spec 099).
enum LaunchSplashPhase: Equatable {
  /// The 1.2 s brand entrance is still running.
  case playing
  /// Entrance done, first screen not ready: hold the last frame, loader keeps sweeping.
  case loading
  /// First screen ready: the whole layer fades out.
  case exiting
  /// Gone for the rest of the process; a warm start never brings it back.
  case removed

  static func resolve(
    animationFinished: Bool,
    firstScreenReady: Bool,
    reduceMotion: Bool,
    exitFinished: Bool
  ) -> LaunchSplashPhase {
    if exitFinished { return .removed }
    // Reduce Motion skips the entrance and starts from the last frame.
    guard animationFinished || reduceMotion else { return .playing }
    return firstScreenReady ? .exiting : .loading
  }
}
