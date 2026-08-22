import AVKit
import Foundation

extension FeedbackVideoPlayerView {
  static let coachExportConfirmationDefaultsKey =
    "meetpr.videoBadge.coachExportConsentConfirmed"

  func retry() {
    retrying = true
    Task {
      defer { retrying = false }
      guard let fresh = try? await refreshURL(videoID) else {
        return
      }
      playbackFailed = false
      // Replacing the item resumes playback: the annotation overlay's
      // paused-frame contract cannot hold across the swap, so close it.
      closeAnnotation()
      player.replaceCurrentItem(with: AVPlayerItem(url: fresh))
      playbackURL = fresh
      player.defaultRate = rate
      switch playbackBehavior.retryCommand {
      case .none:
        break
      case .play:
        player.play()
      case .playImmediatelyAtSelectedRate:
        player.playImmediately(atRate: rate)
      }
      isPlaying = true
    }
  }

  func cycleRate() {
    if playbackBehavior == .legacyFullScreen {
      let index = Self.rates.firstIndex(of: rate) ?? 1
      rate = Self.rates[(index + 1) % Self.rates.count]
      player.defaultRate = rate
      if player.timeControlStatus == .playing {
        player.rate = rate
      }
    } else {
      let index = Self.rates.firstIndex(of: rate) ?? 1
      selectRate(Self.rates[(index + 1) % Self.rates.count])
    }
  }

  func selectRate(_ selectedRate: Float) {
    rate = selectedRate
    player.defaultRate = selectedRate
    if playbackBehavior.appliesSelectedRate(while: player.timeControlStatus) {
      player.rate = selectedRate
    }
  }

  func togglePlayback() {
    if isPlaying {
      player.pause()
      isPlaying = false
    } else {
      if currentSeconds >= durationSeconds, durationSeconds > 0 {
        player.seek(to: .zero)
      }
      player.playImmediately(atRate: rate)
      isPlaying = true
    }
  }

  func requestExport() {
    guard !isExporting else { return }
    if requiresCoachExportConfirmation,
      !UserDefaults.standard.bool(forKey: Self.coachExportConfirmationDefaultsKey)
    {
      showingCoachExportConfirmation = true
      return
    }
    startExport()
  }

  func startExport() {
    #if os(iOS)
      guard let badge, !isExporting else { return }
      isExporting = true
      showingSavedToast = false
      exportTask = Task {
        do {
          let outputURL = try await VideoBadgeExporter().export(
            sourceURL: playbackURL,
            badge: badge
          )
          defer { try? FileManager.default.removeItem(at: outputURL) }
          try Task.checkCancellation()
          try await VideoBadgePhotoLibrary.save(outputURL)
          try Task.checkCancellation()
          showingSavedToast = true
          try? await Task.sleep(for: .seconds(2.5))
          showingSavedToast = false
        } catch is CancellationError {
          showingSavedToast = false
        } catch VideoBadgePhotoLibraryError.permissionDenied {
          exportFailureMessage = ChatStrings.videoExportPhotoPermissionDenied
          showingExportFailure = true
        } catch {
          exportFailureMessage = ChatStrings.videoExportFailureMessage
          showingExportFailure = true
        }
        isExporting = false
        exportTask = nil
      }
    #endif
  }
}
