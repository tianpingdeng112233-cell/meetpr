#if os(iOS)
  import Photos

  enum VideoLibrarySaver {
    static func requestAuthorization() async -> Bool {
      let current = PHPhotoLibrary.authorizationStatus(for: .addOnly)
      let status =
        current == .notDetermined
        ? await PHPhotoLibrary.requestAuthorization(for: .addOnly)
        : current
      return status == .authorized || status == .limited
    }

    static func save(_ url: URL) async -> Bool {
      guard await requestAuthorization() else { return false }
      do {
        try await PHPhotoLibrary.shared().performChanges {
          PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
        }
        return true
      } catch {
        return false
      }
    }
  }
#endif
