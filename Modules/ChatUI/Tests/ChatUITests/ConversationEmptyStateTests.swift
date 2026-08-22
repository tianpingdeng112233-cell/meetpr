import Testing

@testable import ChatUI

@Test("conversation timeline shows loading before the first empty state")
func conversationTimelineLoadingPrecedesEmpty() {
  #expect(
    ConversationTimelinePresentation.resolve(
      didFinishInitialLoad: false,
      hasLoadError: false,
      hasMessages: false,
      hasPendingMessages: false
    ) == .loading
  )
  #expect(
    ConversationTimelinePresentation.resolve(
      didFinishInitialLoad: false,
      hasLoadError: true,
      hasMessages: false,
      hasPendingMessages: false
    ) == .failed
  )
  #expect(
    ConversationTimelinePresentation.resolve(
      didFinishInitialLoad: true,
      hasLoadError: false,
      hasMessages: false,
      hasPendingMessages: false
    ) == .empty
  )
  #expect(
    ConversationTimelinePresentation.resolve(
      didFinishInitialLoad: true,
      hasLoadError: false,
      hasMessages: false,
      hasPendingMessages: true
    ) == .content
  )
}

@Test("conversation empty-state copy is localized in Chinese and English")
func conversationEmptyStateCopyIsLocalized() throws {
  #expect(
    try LocalizationCatalogTestSupport.value("chat.noMessages", locale: "zh-Hans")
      == "还没有消息"
  )
  #expect(
    try LocalizationCatalogTestSupport.value("chat.noMessages", locale: "en")
      == "No messages yet"
  )
  #expect(
    try LocalizationCatalogTestSupport.value("chat.noMessagesDescription", locale: "zh-Hans")
      == "开始对话吧"
  )
  #expect(
    try LocalizationCatalogTestSupport.value("chat.noMessagesDescription", locale: "en")
      == "Start the conversation"
  )
}
