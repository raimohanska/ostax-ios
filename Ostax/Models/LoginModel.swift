import Foundation
import Combine

protocol LoginModel: ObservableObject {
    var state: LoginState { get }
    var email: String { get set }
    var code: String { get set }
    func restart()
    func emailLogin()
    func codeLogin()
}

enum LoginState {
    case None, LoggingIn, EmailCodeSent, VerifyingEmailCode, LoggedIn, LoginFailed
}

class RemoteLoginModel: ObservableObject, LoginModel {
    @Published var state: LoginState
    @Published var email: String = UserDefaults.standard.string(forKey: "email") ?? "" {
        didSet {
            UserDefaults.standard.set(email, forKey: "email")
        }
    }
    @Published var code: String = ""

    private let connection: SocketIOConnection
    private var cancelable: Cancellable?
    private var sessionToken: String? = UserDefaults.standard.string(forKey: "sessionToken") {
        didSet {
            UserDefaults.standard.set(sessionToken, forKey: "sessionToken")
        }
    }
    
    init(connection: SocketIOConnection) {
        state = sessionToken != nil ? .LoggingIn : .None
        self.connection = connection
        cancelable = connection.authResponses.sink(receiveValue: { [self] value in
            print("Processing auth response")
            handleAuthResponse(value)
        })
    }
    
    func restart() {
        code = ""
        state = .None
    }
    
    func emailLogin() {
        connection.sendEvent(AuthRequest.EmailLogin(email: email))
        state = .EmailCodeSent
    }
    
    func codeLogin() {
        connection.sendEvent(AuthRequest.EmailCodeValidation(email: email, code: code))
        state = .VerifyingEmailCode
    }

    private func handleAuthResponse(_ event: AuthResponse) {
        switch (event) {
            case .Challenge:
                print("### Auth challenge")
                if let sessionToken = sessionToken {
                    print("### Sending session token \(sessionToken)")
                    connection.sendEvent(AuthRequest.TokenLogin(sessionToken: sessionToken))
                }
            case .EmailLoginResponse(success: let success):
                if (success) {
                    print("Email code sent")
                } else {
                    print("Email code send failed")
                    self.state = .LoginFailed
                }
            case .EmailCodeResponse(success: let success, sessionToken: let newSessionToken):
                if (success) {
                    print("Email code response: success")
                    self.sessionToken = newSessionToken!
                    self.state = .LoggedIn
                } else {
                    print("Email code response: failed")
                    self.state = .LoginFailed
                }
            case .TokenLoginResponse(success: let success):
                if (success) {
                    print("Token login response: success")
                    self.state = .LoggedIn
                } else {
                    print("Token login response: failed")
                    self.state = .LoginFailed
                }
        }
    }
}
