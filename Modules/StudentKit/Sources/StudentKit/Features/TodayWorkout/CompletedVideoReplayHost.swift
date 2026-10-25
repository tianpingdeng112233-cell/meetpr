import SwiftUI

struct CompletedVideoReplayHost: ViewModifier {
  @Bindable var model: CompletedVideoReplayModel

  func body(content: Content) -> some View {
    #if os(iOS)
      content.fullScreenCover(item: $model.selected) { request in
        CompletedVideoReplayView(model: model, request: request)
      }
    #else
      content.sheet(item: $model.selected) { request in
        CompletedVideoReplayView(model: model, request: request)
      }
    #endif
  }
}
