struct VideoTrackCandidate: Sendable {
  let isEnabled: Bool
  let width: Double
  let height: Double
}

enum VideoMainTrackSelection {
  static func index(in tracks: [VideoTrackCandidate]) -> Int? {
    var selected: Int?
    var largestArea = 0.0
    for (index, track) in tracks.enumerated() where track.isEnabled {
      let area = abs(track.width * track.height)
      guard area.isFinite, area > 0 else { continue }
      if selected == nil || area > largestArea {
        selected = index
        largestArea = area
      }
    }
    return selected
  }
}
