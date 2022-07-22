//
//  LoginModel.swift
//  Ostax
//
//  Created by Juha Paananen on 22.7.2022.
//

import Foundation
import Combine

protocol LoginModel {
    var state: LoginState { get }
    func emailLogin(email: String)
    func codeLogin(email: String, code: String)
}

enum LoginState {
    case None, LoggingIn, LoggedIn
}

class RemoteLoginModel: ObservableObject, LoginModel {
    @Published var state: LoginState

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
    
    func emailLogin(email: String) {
        connection.sendEvent(AuthRequest.EmailLogin(email: email))
    }
    
    func codeLogin(email: String, code: String) {
        connection.sendEvent(AuthRequest.EmailCodeValidation(email: email, code: code))
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
                    self.state = .None
                }
            case .EmailCodeResponse(success: let success, sessionToken: let newSessionToken):
                if (success) {
                    print("Email code response: success")
                    self.sessionToken = newSessionToken!
                    self.state = .LoggedIn
                } else {
                    print("Email code response: failed")
                    self.state = .None
                }
            case .TokenLoginResponse(success: let success):
                if (success) {
                    print("Token login response: success")
                    self.state = .LoggedIn
                } else {
                    print("Token login response: failed")
                    self.state = .None
                }
        }
    }
}
