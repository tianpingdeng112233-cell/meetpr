enum ConversationTimelinePresentation: Equatable {
  case loading
  case failed
  case empty
  case content

  static func resolve(
    didFinishInitialLoad: Bool,
    hasLoadError: Bool,
    hasMessages: Bool,
    hasPendingMessages: Bool
  ) -> ConversationTimelinePresentation {
    if !didFinishInitialLoad {
      return hasLoadError ? .failed : .loading
    }
    return hasMessages || hasPendingMessages ? .content : .empty
  }
}
