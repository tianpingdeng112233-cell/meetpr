import AVFoundation
import Foundation
import Observation

/// Owns a single AVPlayer for the lifetime of the set entry, including expansion.
@MainActor @Observable
final class SetEntryVideoPlayer {
  let state = SetEntryVideoPlaybackState()
  private(set) var player: AVPlayer?
  private(set) var attachmentID: UUID?
  private(set) var hasError = false
  private var source: VideoAttachmentPlaybackSource?
  @ObservationIgnored private var monitor: Task<Void, Never>?
  @ObservationIgnored private var seekGeneration = 0
  @ObservationIgnored private var surfaces: [SurfaceRole: AVPlayerLayer] = [:]
  private var isSeeking = false

  func load(attachmentID: UUID, source: VideoAttachmentPlaybackSource) {
    guard self.attachmentID != attachmentID || player == nil else { return }
    stop()
    self.attachmentID = attachmentID
    self.source = source
    player = AVPlayer(url: source.url)
    startMonitoring()
  }

  /// Where a rendering surface lives; the expansion state picks which one shows the video.
  enum SurfaceRole: Sendable { case inline, expanded }

  /// SwiftUI may update the outgoing surface again, and dismantle it, after the incoming one
  /// has attached. Binding follows the expansion state rather than call order, so a late
  /// update or teardown of the old surface cannot take the player away from the new one.
  func attach(to layer: AVPlayerLayer, role: SurfaceRole) {
    if let replaced = surfaces[role], replaced !== layer { replaced.player = nil }
    surfaces[role] = layer
    bindSurface()
  }

  func detach(from layer: AVPlayerLayer, role: SurfaceRole) {
    if surfaces[role] === layer { surfaces[role] = nil }
    layer.player = nil
    bindSurface()
  }

  private func bindSurface() {
    let preferred: SurfaceRole = state.isExpanded ? .expanded : .inline
    let fallback: SurfaceRole = preferred == .expanded ? .inline : .expanded
    let target = surfaces[preferred] ?? surfaces[fallback]
    for layer in surfaces.values where layer !== target && layer.player != nil {
      layer.player = nil
    }
    if let target, target.player !== player { target.player = player }
  }

  func togglePlayback() {
    guard let player else { return }
    if !state.isPlaying, state.duration > 0, state.position >= state.duration {
      seek(to: 0)
    }
    state.togglePlayback()
    if state.isPlaying {
      player.playImmediately(atRate: Float(state.speed.rawValue))
    } else {
      player.pause()
    }
  }

  func setSpeed(_ speed: SetEntryVideoPlaybackState.Speed) {
    state.setSpeed(speed)
    if state.isPlaying { player?.rate = Float(speed.rawValue) }
  }

  func seek(to seconds: Double) {
    state.seek(to: seconds)
    guard let player else { return }
    seekGeneration += 1
    let generation = seekGeneration
    isSeeking = true
    let target = CMTime(seconds: state.position, preferredTimescale: 600)
    Task { [weak self] in
      await player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
      guard let self, generation == seekGeneration else { return }
      isSeeking = false
    }
  }

  func retry(refreshRemoteURL: @MainActor (UUID) async throws -> URL) async {
    guard let attachmentID, let source else { return }
    do {
      let url = try await source.retryURL(
        attachmentID: attachmentID, refreshRemoteURL: refreshRemoteURL)
      guard self.attachmentID == attachmentID else { return }
      hasError = false
      player?.replaceCurrentItem(with: AVPlayerItem(url: url))
      seek(to: state.position)
      if state.isPlaying { player?.playImmediately(atRate: Float(state.speed.rawValue)) }
    } catch {
      guard self.attachmentID == attachmentID else { return }
      hasError = true
    }
  }

  func stop() {
    monitor?.cancel()
    monitor = nil
    player?.pause()
    player?.replaceCurrentItem(with: nil)
    for layer in surfaces.values { layer.player = nil }
    surfaces.removeAll()
    player = nil
    attachmentID = nil
    source = nil
    hasError = false
    isSeeking = false
    seekGeneration += 1
    state.stop()
  }

  private func startMonitoring() {
    monitor = Task { [weak self] in
      while !Task.isCancelled {
        guard self != nil else { return }
        self?.updatePlayback()
        do { try await Task.sleep(for: .milliseconds(200)) } catch { return }
      }
    }
  }

  private func updatePlayback() {
    guard let player, let item = player.currentItem else { return }
    hasError = item.status == .failed
    state.updateDuration(item.duration.seconds)
    if !isSeeking { state.seek(to: player.currentTime().seconds) }
    if hasError || (state.duration > 0 && state.position >= state.duration) {
      state.pause()
    }
  }
}
