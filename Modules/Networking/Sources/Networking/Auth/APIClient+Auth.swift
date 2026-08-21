import CoreModels
import Foundation

extension APIClient {
  public func register(
    phone: String,
    password: String,
    role: UserRole
  ) async throws -> AuthResultDTO {
    let body = AuthRegisterRequestDTO(phone: phone, password: password, role: role)
    return try await postJSON(body, to: .authRegister, as: AuthResultDTO.self)
  }

  public func login(phone: String, password: String) async throws -> AuthResultDTO {
    let body = AuthLoginRequestDTO(phone: phone, password: password)
    return try await postJSON(body, to: .authLogin, as: AuthResultDTO.self)
  }

  public func refresh(refreshToken: String) async throws -> AuthRefreshResponseDTO {
    let body = AuthRefreshRequestDTO(refreshToken: refreshToken)
    return try await postJSON(body, to: .authRefresh, as: AuthRefreshResponseDTO.self)
  }

  public func fetchAuthChallenge() async throws -> AuthChallengeDTO {
    try await postGlobalJSON(EmptyRequestDTO(), to: .authChallenge, as: AuthChallengeDTO.self)
  }

  public func signInWithApple(_ request: AppleAuthRequestDTO) async throws -> AuthResultDTO {
    try await postGlobalJSON(request, to: .authApple, as: AuthResultDTO.self)
  }

  public func signInWithGoogle(_ request: GoogleAuthRequestDTO) async throws -> AuthResultDTO {
    try await postGlobalJSON(request, to: .authGoogle, as: AuthResultDTO.self)
  }

  public func registerWithEmail(_ request: EmailRegisterRequestDTO) async throws -> AuthResultDTO {
    try await postGlobalJSON(request, to: .authEmailRegister, as: AuthResultDTO.self)
  }

  public func loginWithEmail(_ request: EmailLoginRequestDTO) async throws -> AuthResultDTO {
    try await postGlobalJSON(request, to: .authEmailLogin, as: AuthResultDTO.self)
  }

  public func requestPasswordReset(_ request: EmailForgotRequestDTO) async throws {
    try await postGlobalJSONNoContent(request, to: .authEmailForgot)
  }

  public func resetPassword(_ request: EmailResetRequestDTO) async throws {
    try await postGlobalJSONNoContent(request, to: .authEmailReset)
  }

  public func updateTimezone(_ timezone: String, accessToken: String) async throws {
    try await patchNoContent(
      path: Endpoint.meTimezone.path,
      body: TimezoneUpdateRequestDTO(timezone: timezone),
      accessToken: accessToken
    )
  }

  private func postJSON<Request: Encodable, Response: Decodable>(
    _ request: Request,
    to endpoint: Endpoint,
    as responseType: Response.Type
  ) async throws -> Response {
    let body = try MeetPRCodec.encoder.encode(request)
    let data = try await post(endpoint, body: body)
    return try MeetPRCodec.decoder.decode(responseType, from: data)
  }

  /// Global auth shipped after the legacy CN refresh contract and its strict
  /// Zod schemas use camelCase. Do not run these bodies through
  /// `MeetPRCodec.encoder` (`convertToSnakeCase`).
  private func postGlobalJSON<Request: Encodable, Response: Decodable>(
    _ request: Request,
    to endpoint: Endpoint,
    as responseType: Response.Type
  ) async throws -> Response {
    let body = try JSONEncoder().encode(request)
    let data = try await post(endpoint, body: body)
    return try MeetPRCodec.decoder.decode(responseType, from: data)
  }

  private func postGlobalJSONNoContent<Request: Encodable>(
    _ request: Request,
    to endpoint: Endpoint
  ) async throws {
    let body = try JSONEncoder().encode(request)
    _ = try await post(endpoint, body: body)
  }
}

private struct EmptyRequestDTO: Encodable {}
