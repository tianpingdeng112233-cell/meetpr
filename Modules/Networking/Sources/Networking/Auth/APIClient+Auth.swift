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

  private func postJSON<Request: Encodable, Response: Decodable>(
    _ request: Request,
    to endpoint: Endpoint,
    as responseType: Response.Type
  ) async throws -> Response {
    let body = try MeetPRCodec.encoder.encode(request)
    let data = try await post(endpoint, body: body)
    return try MeetPRCodec.decoder.decode(responseType, from: data)
  }
}
