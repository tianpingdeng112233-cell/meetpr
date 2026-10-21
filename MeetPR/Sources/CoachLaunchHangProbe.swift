#if DEMO_MODE && COACH_LAUNCH_HANG_TESTING
  import Foundation

  /// Cold-launch regression watchdog. Excluded from regular Demo and shipping builds.
  enum CoachLaunchHangProbe {
    static func start() {
      guard ProcessInfo.processInfo.arguments.contains("-coach-launch-hang-probe") else { return }
      Task.detached {
        try? await Task.sleep(for: .seconds(1))
        let state = CoachLaunchHangProbeState()
        let start = ContinuousClock.now
        Task { @MainActor in
          await state.respond(elapsed: start.duration(to: .now))
        }
        try? await Task.sleep(for: .seconds(3))
        let elapsed = await state.elapsed
        let message: String
        if let elapsed, elapsed <= .seconds(3) {
          message = "PASS mainResponse=\(elapsed)"
        } else {
          message = "FAIL mainResponse>3s elapsed=\(elapsed.map { "\($0)" } ?? "pending")"
        }
        let data = Data("COACH-LAUNCH-REGRESSION \(message)\n".utf8)
        if let path = ProcessInfo.processInfo.environment["COACH_HANG_PROBE_OUTPUT"] {
          try? data.write(to: URL(fileURLWithPath: path), options: .atomic)
        }
      }
    }
  }

  private actor CoachLaunchHangProbeState {
    var elapsed: Duration?
    func respond(elapsed: Duration) { self.elapsed = elapsed }
  }
#endif
