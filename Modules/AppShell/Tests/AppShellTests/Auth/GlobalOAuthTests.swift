import Foundation
import Testing

@testable import AppShell

@Test func appleNonceHashUsesLowercaseSHA256Hex() {
  #expect(
    GlobalAuthCrypto.sha256Hex("plain-nonce")
      == "76446287817df20d048286fd6b1925d284e82de8587c861216d0ca6c30475a90"
  )
}

@Test func googlePKCEUsesS256AndExpectedAuthorizationParameters() throws {
  let verifier = "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk"
  #expect(
    GlobalAuthCrypto.codeChallenge(for: verifier)
      == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM"
  )

  let configuration = GoogleOAuthConfiguration.meetPR
  let url = try configuration.authorizationURL(
    codeChallenge: GlobalAuthCrypto.codeChallenge(for: verifier),
    state: "state-074"
  )
  let items = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
  let parameters = Dictionary(
    uniqueKeysWithValues: items.compactMap { item in
      item.value.map { (item.name, $0) }
    })

  #expect(url.host() == "accounts.google.com")
  #expect(parameters["client_id"] == configuration.clientID)
  #expect(parameters["redirect_uri"] == configuration.redirectURI)
  #expect(parameters["response_type"] == "code")
  #expect(parameters["scope"] == "openid email profile")
  #expect(parameters["code_challenge_method"] == "S256")
  #expect(parameters["state"] == "state-074")
}

@MainActor
@available(iOS 17.0, macOS 14.0, *)
@Test func googleTokenExchangeUsesPKCEWithoutClientSecretAndParsesIDToken() async throws {
  let capture = GoogleRequestCapture()
  let service = GoogleOAuthService { request in
    await capture.record(request)
    return GoogleOAuthHTTPResponse(
      data: Data(#"{"id_token":"google-id-token"}"#.utf8),
      statusCode: 200
    )
  }

  let idToken = try await service.exchangeCode("authorization-code", verifier: "pkce-verifier")
  let request = try #require(await capture.request())
  let body = try #require(request.httpBody.flatMap { String(data: $0, encoding: .utf8) })

  #expect(idToken == "google-id-token")
  #expect(request.url?.absoluteString == "https://oauth2.googleapis.com/token")
  #expect(request.httpMethod == "POST")
  #expect(request.value(forHTTPHeaderField: "content-type") == "application/x-www-form-urlencoded")
  #expect(body.contains("code=authorization-code"))
  #expect(body.contains("code_verifier=pkce-verifier"))
  #expect(body.contains("grant_type=authorization_code"))
  #expect(!body.localizedStandardContains("client_secret"))
}

private actor GoogleRequestCapture {
  private var capturedRequest: URLRequest?

  func record(_ request: URLRequest) {
    capturedRequest = request
  }

  func request() -> URLRequest? {
    capturedRequest
  }
}
