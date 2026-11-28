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
      await save(.file(url))
    }

    static func save(_ source: RecordingAlbumSource) async -> Bool {
      guard await requestAuthorization() else { return false }
      do {
        try await PHPhotoLibrary.shared().performChanges {
          switch source {
          case .file(let url):
            PHAssetCreationRequest.forAsset().addResource(with: .video, fileURL: url, options: nil)
          case .mappedOriginal(let data, let filename):
            let options = PHAssetResourceCreationOptions()
            options.originalFilename = filename
            PHAssetCreationRequest.forAsset().addResource(
              with: .video, data: data, options: options)
          }
        }
        return true
      } catch {
        return false
      }
    }
  }
#endif
