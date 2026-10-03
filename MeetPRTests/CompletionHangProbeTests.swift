// Temporary phase-1 diagnostic harness; see docs/diagnose/completion-hang-2026-10-03.md.
// A passing run is not a regression test until the reported hang reproduces here.
#if COMPLETION_HANG_PROBE
  import AppShell
  import CoreFoundation
  import CoreModels
  import SwiftUI
  import Testing
  import UIKit

  @testable import StudentKit

  @Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["HANG_PROBE"] == "1"))
  @MainActor
  struct CompletionHangProbeTests {
    @Test func mountedWorkoutReturnsToIdleAfterCompletion() async throws {
      let scene = try #require(
        UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
      )
      let window = UIWindow(windowScene: scene)
      window.windowLevel = .alert
      let idle = HangProbeIdleCounter()
      let observer = try #require(
        CFRunLoopObserverCreateWithHandler(
          nil, CFRunLoopActivity.beforeWaiting.rawValue, true, 0
        ) { _, _ in
          MainActor.assumeIsolated { idle.count += 1 }
        }
      )
      CFRunLoopAddObserver(CFRunLoopGetMain(), observer, .commonModes)
      defer {
        CFRunLoopRemoveObserver(CFRunLoopGetMain(), observer, .commonModes)
        window.isHidden = true
        window.rootViewController = nil
      }

      let iterations =
        Int(ProcessInfo.processInfo.environment["HANG_PROBE_ITERATIONS"] ?? "24") ?? 24
      for iteration in 0..<iterations {
        let watchdog = Task.detached {
          do { try await Task.sleep(for: .seconds(8)) } catch { return }
          fatalError("HANG-PROBE timeout: main run loop did not finish iteration \(iteration)")
        }
        defer { watchdog.cancel() }
        try await runIteration(iteration, window: window, idle: idle)
      }
    }

    private func runIteration(
      _ iteration: Int, window: UIWindow, idle: HangProbeIdleCounter
    ) async throws {
      let now = Date(timeIntervalSince1970: 1_791_014_400)
      let plan = StudentDemoSeed.makePlanView(today: now)
      let day = try #require(StudentPlanSequence.cursorDay(in: plan))
      let store = InMemoryPlanStore()
      await store.savePublishedProjection(plan, forStudent: StudentDemoSeed.studentID)
      let plans = InMemoryStudentPlanRepository(store: store, now: { now })
      let logs = InMemoryStudentTrainingLogRepository()
      let viewModel = TodayWorkoutViewModel(plans: plans, logs: logs, now: { now })
      await viewModel.load(dayID: day.id, studentID: StudentDemoSeed.studentID)
      let rowCount = try await prepareFirstSets(viewModel)
      let host = UIHostingController(
        rootView: TodayWorkoutView(
          studentID: StudentDemoSeed.studentID, date: day.scheduledDate,
          plans: plans, logs: logs, preloadedViewModel: viewModel, started: true
        )
        .environment(\.locale, Locale(identifier: "en"))
      )
      window.rootViewController = host
      window.makeKeyAndVisible()
      try await Task.sleep(for: .milliseconds(150))
      let sheetEnabled = ProcessInfo.processInfo.environment["HANG_PROBE_SHEET"] == "1"
      var entryHost: UIViewController?
      if sheetEnabled {
        let entry = try makeEntryHost(viewModel: viewModel, day: day, rowCount: rowCount)
        host.present(entry, animated: true)
        entryHost = entry
        try await Task.sleep(for: .milliseconds(450))
      }
      #expect(await viewModel.commitSet(rowIndex: rowCount - 1))
      entryHost?.dismiss(animated: true)
      let delay = [0, 16, 50, 100, 200, 350][iteration % 6]
      try await Task.sleep(for: .milliseconds(delay))
      try scrollToBottom(in: host.view, animated: iteration % 2 == 0)
      if sheetEnabled {
        // Match the hold duration, while beginning the scroll during cover dismissal.
        try await Task.sleep(for: .milliseconds(1_100))
      }
      let before = idle.count
      #expect(await viewModel.completeCurrentDay())
      try await Task.sleep(for: .milliseconds(700))
      #expect(idle.count > before, "Main run loop never returned to beforeWaiting")
      #expect(host.presentedViewController != nil, "Reward was not presented")
      print(
        "HANG-PROBE PASS iteration=\(iteration) sheet=\(sheetEnabled) "
          + "delayMs=\(delay) idleDelta=\(idle.count - before)")
      viewModel.completionPhase = nil
      try await Task.sleep(for: .milliseconds(350))
      window.rootViewController = nil
    }

    private func findScrollView(in view: UIView) -> UIScrollView? {
      if let scroll = view as? UIScrollView { return scroll }
      return view.subviews.lazy.compactMap { findScrollView(in: $0) }.first
    }

    private func scrollToBottom(in view: UIView, animated: Bool) throws {
      let scroll = try #require(findScrollView(in: view))
      let bottom = max(
        -scroll.adjustedContentInset.top,
        scroll.contentSize.height - scroll.bounds.height + scroll.adjustedContentInset.bottom)
      scroll.setContentOffset(CGPoint(x: 0, y: bottom), animated: animated)
    }

    private func prepareFirstSets(_ viewModel: TodayWorkoutViewModel) async throws -> Int {
      let rowCount = try #require(viewModel.currentDrafts?.count)
      #expect(rowCount == 3)
      for index in 0..<(rowCount - 1) {
        #expect(await viewModel.commitSet(rowIndex: index))
      }
      viewModel.acknowledgeRestTimerExplanation()
      viewModel.skipRestTimer()
      return rowCount
    }

    private func makeEntryHost(
      viewModel: TodayWorkoutViewModel, day: StudentPlanDay, rowCount: Int
    ) throws -> UIViewController {
      let draft = try #require(viewModel.currentDrafts?.last)
      let entry = UIHostingController(
        rootView: SetEntrySheet(
          rowIndex: rowCount - 1, draft: draft, setNumber: rowCount,
          viewModel: viewModel, studentID: StudentDemoSeed.studentID,
          trainingDate: day.scheduledDate
        )
      )
      entry.modalPresentationStyle = .fullScreen
      return entry
    }
  }

  @MainActor
  private final class HangProbeIdleCounter {
    var count = 0
  }
#endif
