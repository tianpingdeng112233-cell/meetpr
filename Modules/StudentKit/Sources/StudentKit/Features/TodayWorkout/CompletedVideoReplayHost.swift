import SwiftUI

struct CompletedVideoReplayHost: ViewModifier {
  @Bindable var model: CompletedVideoReplayModel
  var onDismiss: () -> Void = {}

  func body(content: Content) -> some View {
    #if os(iOS)
      content.fullScreenCover(item: $model.selected, onDismiss: onDismiss) { request in
        CompletedVideoReplayView(model: model, request: request)
      }
    #else
      content.sheet(item: $model.selected, onDismiss: onDismiss) { request in
        CompletedVideoReplayView(model: model, request: request)
      }
    #endif
  }
}
