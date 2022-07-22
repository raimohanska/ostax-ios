import Foundation

enum AuthRequest {
    case EmailLogin(email: String)
    case EmailCodeValidation(email: String, code: String)
    case TokenLogin(sessionToken: String)
}

extension AuthRequest: Codable, SendableEvent {
    static let eventType = "auth-request"
    
    enum CodingKeys: String, CodingKey {
        case EmailLogin = "email-login"
        case EmailCodeValidation = "email-code-validation"
        case TokenLogin = "token-login"
    }
}
