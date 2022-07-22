import Foundation

enum AuthResponse {
    case Challenge
    case EmailLoginResponse(success: Bool)
    case EmailCodeResponse(success: Bool, sessionToken: String?)
    case TokenLoginResponse(success: Bool)
}

extension AuthResponse: Codable {
    enum CodingKeys: String, CodingKey {
        case Challenge = "challenge"
        case EmailCodeResponse = "email-code-response"
        case EmailLoginResponse = "email-login-response"
        case TokenLoginResponse = "token-login-response"
    }
}
