import AVFoundation

enum AVAssetMainVideoTrack {
  static func select(from tracks: [AVAssetTrack]) async throws -> AVAssetTrack? {
    var candidates: [VideoTrackCandidate] = []
    for track in tracks {
      let enabled = try await track.load(.isEnabled)
      let size = try await track.load(.naturalSize)
      candidates.append(
        VideoTrackCandidate(isEnabled: enabled, width: size.width, height: size.height)
      )
    }
    guard let index = VideoMainTrackSelection.index(in: candidates) else { return nil }
    return tracks[index]
  }
  /// A single-video preview prevents AVPlayer/ImageGenerator from choosing a
  /// secondary cinematic track. The upload still reads the untouched source.
  static func previewAsset(
    source: AVAsset, mainTrack: AVAssetTrack, videoTrackCount: Int
  ) async throws -> AVAsset {
    guard videoTrackCount > 1 else { return source }
    let composition = AVMutableComposition()
    var tracks = [mainTrack]
    if let audio = try await source.loadTracks(withMediaType: .audio).first {
      tracks.append(audio)
    }
    for track in tracks {
      guard
        let copy = composition.addMutableTrack(
          withMediaType: track.mediaType, preferredTrackID: kCMPersistentTrackID_Invalid)
      else { throw VideoUploadError.exportFailed("Unable to create main-track preview") }
      let range = try await track.load(.timeRange)
      try copy.insertTimeRange(range, of: track, at: range.start)
      copy.preferredTransform = try await track.load(.preferredTransform)
    }
    return composition
  }
}
