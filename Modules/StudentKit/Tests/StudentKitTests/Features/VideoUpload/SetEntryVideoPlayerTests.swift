import AVFoundation
import ChatUI
import Foundation
import SwiftUI
import Testing
import ViewInspector

@testable import StudentKit

@Suite @MainActor struct SetEntryVideoPlayerTests {
  @Test(arguments: [false, true])
  func centralPlayButtonFollowsPlaybackAndRestartsAtEnd(expanded: Bool) throws {
    let playback = SetEntryVideoPlayer()
    playback.load(attachmentID: UUID(), source: .local(URL(filePath: "/tmp/unused-video.mp4")))
    defer { playback.stop() }
    if expanded { playback.state.toggleExpanded() }
    let view = SetEntryVideoPlayerView(playback: playback, badge: nil, retry: {})
    let identifier = "setEntryVideo.centralPlay"
    let button = try view.inspect().find(viewWithAccessibilityIdentifier: identifier).button()
    #expect(
      try button.accessibilityLabel().string() == StudentStrings.localized(.setEntryVideoPlay))
    try button.tap()
    #expect(playback.state.isPlaying)
    #expect((try? view.inspect().find(viewWithAccessibilityIdentifier: identifier)) == nil)

    playback.togglePlayback()
    #expect(!playback.state.isPlaying)
    #expect((try? view.inspect().find(viewWithAccessibilityIdentifier: identifier)) != nil)
    playback.state.updateDuration(10)
    playback.state.seek(to: 10)
    try view.inspect().find(viewWithAccessibilityIdentifier: identifier).button().tap()
    #expect(playback.state.isPlaying)
    #expect(playback.state.position == 0)
    #expect((try? view.inspect().find(viewWithAccessibilityIdentifier: identifier)) == nil)
  }

  @Test func surfaceHandoffExclusivelyBindsPlayerAndIgnoresLateDetach() throws {
    let playback = SetEntryVideoPlayer()
    playback.load(attachmentID: UUID(), source: .local(URL(filePath: "/tmp/unused-video.mp4")))
    defer { playback.stop() }
    let player = try #require(playback.player)
    let item = try #require(player.currentItem)
    let inline = AVPlayerLayer()
    let expanded = AVPlayerLayer()
    playback.attach(to: inline, role: .inline)
    #expect(inline.player === player)
    playback.setSpeed(.half)
    playback.togglePlayback()

    // SwiftUI can create the destination before dismantling the old host.
    playback.state.toggleExpanded()
    playback.attach(to: expanded, role: .expanded)
    #expect(inline.player == nil)
    #expect(expanded.player === player)
    playback.detach(from: inline, role: .inline)
    #expect(expanded.player === player)
    playback.state.toggleExpanded()
    playback.attach(to: inline, role: .inline)
    #expect(expanded.player == nil)
    playback.detach(from: expanded, role: .expanded)
    #expect(inline.player === player)
    #expect(playback.player === player)
    #expect(player.currentItem === item)
    #expect(playback.state.isPlaying)
    #expect(playback.state.speed == .half)

    // Also cover teardown before the replacement host is created.
    playback.detach(from: inline, role: .inline)
    #expect(inline.player == nil)
    playback.state.toggleExpanded()
    playback.attach(to: expanded, role: .expanded)
    #expect(expanded.player === player)
    playback.stop()
    #expect(expanded.player == nil)
  }

  /// Simulator trace 2026-10-03: after expanding, SwiftUI updated the outgoing inline
  /// surface once more before dismantling it, which stole the player back and then
  /// cleared it, leaving the expanded surface black.
  @Test func staleUpdateFromOutgoingSurfaceDoesNotStealPlayer() throws {
    let playback = SetEntryVideoPlayer()
    playback.load(attachmentID: UUID(), source: .local(URL(filePath: "/tmp/unused-video.mp4")))
    defer { playback.stop() }
    let player = try #require(playback.player)
    let inline = AVPlayerLayer()
    let expanded = AVPlayerLayer()
    playback.attach(to: inline, role: .inline)

    playback.state.toggleExpanded()
    playback.attach(to: expanded, role: .expanded)
    playback.attach(to: inline, role: .inline)
    playback.detach(from: inline, role: .inline)
    #expect(expanded.player === player)
    #expect(inline.player == nil)

    playback.state.toggleExpanded()
    playback.attach(to: inline, role: .inline)
    playback.attach(to: expanded, role: .expanded)
    playback.detach(from: expanded, role: .expanded)
    #expect(inline.player === player)
    #expect(expanded.player == nil)

    let replacement = AVPlayerLayer()
    playback.attach(to: replacement, role: .inline)
    #expect(inline.player == nil)
    #expect(replacement.player === player)
  }

  #if os(macOS)
    @Test func resizingPlayerSurfacePreservesActualPlaybackTime() async throws {
      var root = URL(filePath: #filePath)
      for _ in 0..<7 { root.deleteLastPathComponent() }
      let source = root.appending(path: "MeetPR/Resources/coach-demo-video.mp4")
      let playback = SetEntryVideoPlayer()
      playback.load(attachmentID: UUID(), source: .local(source))
      defer { playback.stop() }
      let player = try #require(playback.player)
      let item = try #require(player.currentItem)
      let host = NSHostingView(
        rootView: SetEntryVideoPlayerView(
          playback: playback, badge: nil, retry: {}))
      host.frame = CGRect(x: 0, y: 0, width: 320, height: 240)
      host.layoutSubtreeIfNeeded()
      try await seekPastStart(playback)
      #expect(playback.state.position >= 0.9)
      playback.setSpeed(.oneAndHalf)
      playback.state.toggleExpanded()
      host.frame.size.height = 700
      host.layoutSubtreeIfNeeded()
      try await Task.sleep(for: .milliseconds(250))
      #expect(player.currentTime().seconds >= 0.9)
      #expect(playback.state.position >= 0.9)
      #expect(player.currentItem === item)
      #expect(!playback.state.isPlaying)
      playback.state.handleBack()
      host.frame.size.height = 240
      host.layoutSubtreeIfNeeded()
      try await Task.sleep(for: .milliseconds(250))
      #expect(player.currentTime().seconds >= 0.9)
      #expect(playback.state.position >= 0.9)
      #expect(playback.player === player)
      #expect(player.currentItem === item)
      #expect(playback.state.speed == .oneAndHalf)
      #expect(!playback.state.isPlaying)
      // Verify the playing intent synchronously; media decoding is a device check.
      playback.togglePlayback()
      playback.state.toggleExpanded()
      playback.load(attachmentID: try #require(playback.attachmentID), source: .local(source))
      #expect(playback.state.isPlaying)
      #expect(player.currentTime().seconds >= 0.9)
      #expect(playback.state.handleBack())
      #expect(playback.state.isPlaying)
      #expect(player.currentItem === item)
      #expect(playback.state.speed == .oneAndHalf)
      playback.togglePlayback()
      #expect(!playback.state.isPlaying)
    }
  #endif

  private func seekPastStart(_ playback: SetEntryVideoPlayer) async throws {
    let player = try #require(playback.player)
    let item = try #require(player.currentItem)
    for _ in 0..<100 where item.status == .unknown {
      try await Task.sleep(for: .milliseconds(20))
    }
    playback.state.updateDuration(try await item.asset.load(.duration).seconds)
    await player.seek(
      to: CMTime(seconds: 1, preferredTimescale: 600),
      toleranceBefore: .zero, toleranceAfter: .zero)
    try await Task.sleep(for: .milliseconds(250))
  }

  @Test func expandedHeaderIncludesAvailableSetMetrics() throws {
    let playback = SetEntryVideoPlayer()
    playback.state.toggleExpanded()
    let view = SetEntryVideoPlayerView(
      playback: playback,
      badge: VideoBadgeInfo(weightKg: 175, reps: 3, rpe: 8.5, setOrdinal: 1),
      retry: {})
    let label = StudentStrings.replacing(.setEntryVideoSet, values: ["1"])
    #expect(
      try view.inspect().find(text: "\(label) · 175kg × 3 · RPE 8.5").string()
        == "\(label) · 175kg × 3 · RPE 8.5")
  }

  @Test func expandedHeaderOmitsMissingFields() throws {
    let playback = SetEntryVideoPlayer()
    playback.state.toggleExpanded()
    let view = SetEntryVideoPlayerView(
      playback: playback, badge: VideoBadgeInfo(reps: 3, setOrdinal: 2), retry: {})
    let label = StudentStrings.replacing(.setEntryVideoSet, values: ["2"])
    #expect(try view.inspect().find(text: "\(label) · 3").string() == "\(label) · 3")
  }

  @Test func setOrdinalIsInterpolatedInBothLanguages() {
    #expect(
      StudentStrings.replacing(.setEntryVideoSet, values: ["1"], locale: Locale(identifier: "en"))
        == "Set 1")
    #expect(
      StudentStrings.replacing(
        .setEntryVideoSet, values: ["1"], locale: Locale(identifier: "zh-Hans"))
        == "第 1 组")
  }
}
