import CoreModels
import Foundation
import RepositoryContracts

public actor NetworkChatRepository: ChatRepository {
  private let apiClient: APIClient
  private let session: any SessionStateReader
  private let uploader: OSSPartUploader

  public init(
    apiClient: APIClient,
    session: any SessionStateReader,
    uploader: OSSPartUploader
  ) {
    self.apiClient = apiClient
    self.session = session
    self.uploader = uploader
  }

  public func fetchConversations() async throws -> [ChatConversation] {
    let token = try await session.accessToken()
    do {
      let response: ChatConversationsResponseDTO = try await apiClient.get(
        path: "/conversations",
        accessToken: token
      )
      return response.conversations.map { $0.toDomain() }
    } catch {
      throw Self.mapped(error)
    }
  }

  public func openConversation(
    withOtherParty otherPartyID: UUID
  ) async throws -> ChatConversation {
    let token = try await session.accessToken()
    do {
      let response: ChatConversationResponseDTO = try await apiClient.post(
        path: "/conversations",
        body: ChatOpenConversationRequestDTO(otherUserID: otherPartyID),
        accessToken: token
      )
      return response.conversation.toDomain()
    } catch {
      throw Self.mapped(error)
    }
  }

  public func fetchMessages(
    in conversationID: UUID,
    query: ChatMessageQuery
  ) async throws -> ChatMessagePage {
    let token = try await session.accessToken()
    do {
      let response: ChatMessagesResponseDTO = try await apiClient.get(
        path: "/conversations/\(conversationID.uuidString)/messages",
        queryItems: Self.queryItems(for: query),
        accessToken: token
      )
      return ChatMessagePage(
        messages: response.messages.map { $0.toDomain() },
        otherLastRead: response.meta.otherLastRead?.toDomain(),
        hasMore: response.meta.hasMore
      )
    } catch {
      throw Self.mapped(error)
    }
  }

  public func sendText(
    in conversationID: UUID,
    text: String,
    clientID: String
  ) async throws -> ChatMessage {
    let token = try await session.accessToken()
    do {
      let response: ChatMessageResponseDTO = try await apiClient.post(
        path: "/conversations/\(conversationID.uuidString)/messages",
        body: ChatSendMessageRequestDTO(kind: .text, body: text, clientID: clientID),
        accessToken: token
      )
      return response.message.toDomain()
    } catch {
      throw Self.mapped(error)
    }
  }

  public func sendImage(
    in conversationID: UUID,
    imageData: Data,
    clientID: String
  ) async throws -> ChatMessage {
    let token = try await session.accessToken()
    let attachmentID = try await uploadImage(
      imageData,
      clientID: clientID,
      accessToken: token
    )

    do {
      try Task.checkCancellation()
      let response: ChatMessageResponseDTO = try await apiClient.post(
        path: "/conversations/\(conversationID.uuidString)/messages",
        body: ChatSendMessageRequestDTO(
          kind: .image,
          attachmentID: attachmentID,
          clientID: clientID
        ),
        accessToken: token
      )

      if response.message.attachmentID != attachmentID {
        await cleanupChatAttachment(
          attachmentID,
          completed: true,
          apiClient: apiClient,
          accessToken: token
        )
      }
      return response.message.toDomain()
    } catch {
      await cleanupChatAttachment(
        attachmentID,
        completed: true,
        apiClient: apiClient,
        accessToken: token
      )
      throw Self.mapped(error)
    }
  }

  public func markRead(
    in conversationID: UUID,
    upTo messageID: UUID
  ) async throws -> ChatReadState {
    let token = try await session.accessToken()
    do {
      let response: ChatReadResponseDTO = try await apiClient.post(
        path: "/conversations/\(conversationID.uuidString)/read",
        body: ChatReadRequestDTO(messageID: messageID),
        accessToken: token
      )
      return ChatReadState(
        myLastRead: response.myLastRead.toDomain(),
        unreadCount: response.unreadCount
      )
    } catch {
      throw Self.mapped(error)
    }
  }

  private static func queryItems(for query: ChatMessageQuery) -> [URLQueryItem] {
    var items: [URLQueryItem] = []
    switch query.mode {
    case .latest:
      break
    case .after(let seq):
      items.append(URLQueryItem(name: "since_seq", value: String(seq)))
    case .before(let seq):
      items.append(URLQueryItem(name: "before_seq", value: String(seq)))
    }
    items.append(URLQueryItem(name: "limit", value: String(query.limit)))
    return items
  }

  private func uploadImage(
    _ imageData: Data,
    clientID: String,
    accessToken: String
  ) async throws -> UUID {
    try Task.checkCancellation()
    let initiated = try await apiClient.initiateUpload(
      InitiateUploadRequestDTO(
        kind: .chatImage,
        contentType: "image/jpeg",
        sizeBytes: Int64(imageData.count),
        partCount: 1,
        filename: "chat-\(clientID).jpg"
      ),
      accessToken: accessToken
    )

    do {
      let partURL = try Self.singlePartURL(from: initiated.partURLs)
      try Task.checkCancellation()
      let etag = try await uploader.uploadPart(to: partURL, data: imageData)
      try Task.checkCancellation()
      let attachment = try await apiClient.completeUpload(
        attachmentID: initiated.attachmentID,
        parts: [UploadPartETagDTO(partNumber: 1, etag: etag)],
        accessToken: accessToken
      )
      guard attachment.id == initiated.attachmentID,
        attachment.kind == .chatImage,
        attachment.status == .ready
      else {
        throw APIError.invalidResponse
      }
      return attachment.id
    } catch {
      await cleanupChatAttachment(
        initiated.attachmentID,
        completed: false,
        apiClient: apiClient,
        accessToken: accessToken
      )
      throw Self.mapped(error)
    }
  }

  private static func singlePartURL(from parts: [UploadPartURLDTO]) throws -> URL {
    guard parts.count == 1,
      let part = parts.first,
      part.partNumber == 1,
      let url = URL(string: part.url)
    else {
      throw APIError.invalidResponse
    }
    return url
  }

  private static func mapped(_ error: any Error) -> any Error {
    guard case APIError.httpStatus(let statusCode, _) = error else {
      return error
    }
    switch (statusCode, BackendErrorEnvelope.machineCode(from: error)) {
    case (403, "CHAT_BIND_REQUIRED"):
      return ChatRepositoryError.bindRequired
    case (404, "CONVERSATION_NOT_FOUND"):
      return ChatRepositoryError.conversationNotFound
    case (400, "CHAT_INVALID_ATTACHMENT"):
      return ChatRepositoryError.invalidAttachment
    case (400, "CHAT_INVALID_CURSOR"):
      return ChatRepositoryError.invalidCursor
    default:
      return error
    }
  }

}

private func cleanupChatAttachment(
  _ attachmentID: UUID,
  completed: Bool,
  apiClient: APIClient,
  accessToken: String
) async {
  await Task.detached {
    if !completed {
      do {
        try await apiClient.abortUpload(
          attachmentID: attachmentID,
          accessToken: accessToken
        )
        return
      } catch {
        // Completion may have won a response race. Fall through to DELETE,
        // which safely refuses an attachment already referenced by a message.
      }
    }

    do {
      try await apiClient.deleteNoContent(
        path: "/uploads/\(attachmentID.uuidString)",
        accessToken: accessToken
      )
    } catch {
      let machineCode = BackendErrorEnvelope.machineCode(from: error)
      guard machineCode == "UPLOAD_INVALID_STATE" else {
        // ATTACHMENT_IN_USE means the POST committed and the attachment is
        // no longer orphaned. Other failures remain best-effort cleanup.
        return
      }
      try? await apiClient.postNoContent(
        path: "/uploads/\(attachmentID.uuidString)/reconcile",
        body: EmptyWireBody(),
        accessToken: accessToken
      )
    }
  }.value
}
