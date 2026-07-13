#if os(iOS)
  import Photos

  /// Saves camera captures to the user's photo library before the upload even
  /// starts: a set can't be re-done — it already cost real fatigue — so the
  /// recording must survive any upload failure (David, beta 2026-07-11).
  /// Add-only access; a denial degrades silently (upload still proceeds).
  enum VideoLibrarySaver {
    static func save(_ url: URL) async {
      let status = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
      guard status == .authorized || status == .limited else { return }
      try? await PHPhotoLibrary.shared().performChanges {
        PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
      }
    }
  }
#endif
