import CoreModels

enum VideoMarkerWindow {
  static func active(in markers: [VideoMarker], seconds: Double) -> VideoMarker? {
    markers.lazy.filter {
      let start = Double($0.timeMilliseconds)
      return start / 1_000 <= seconds && seconds < (start + 2_400) / 1_000
    }.max { $0.timeMilliseconds < $1.timeMilliseconds }
  }
}
