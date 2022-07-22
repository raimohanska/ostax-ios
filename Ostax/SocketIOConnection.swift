import Foundation
import SocketIO
import Combine

typealias Dispatch = (AppEvent) -> ()

extension Encodable {
  func asDictionary() throws -> [String: Any] {
    let data = try JSONEncoder().encode(self)
    guard let dictionary = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any] else {
      throw NSError()
    }
    return dictionary
  }
}

protocol LoginController {
    func emailLogin(email: String)
    func codeLogin(email: String, code: String)
}

protocol SendableEvent: Encodable {
    static var eventType: String { get }
}

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

class SocketIOConnection: ObservableObject, LoginController {
    private let manager: SocketManager
    @Published var sessionToken: String? = UserDefaults.standard.string(forKey: "sessionToken") {
        didSet {
            UserDefaults.standard.set(sessionToken, forKey: "sessionToken")
        }
    }
    private let socket: SocketIOClient
    var loggedIn: Bool = false
    let appEvents = PassthroughSubject<AppEvent, Never>()
    
    func emailLogin(email: String) {
        sendEvent(AuthRequest.EmailLogin(email: email))
    }
    
    func codeLogin(email: String, code: String) {
        sendEvent(AuthRequest.EmailCodeValidation(email: email, code: code))
    }
    
    func sendEvent<E : SendableEvent>(_ event: E) {
        do {
            let dict = try event.asDictionary()
            precondition(dict.keys.count == 1)
            let action: String = dict.keys.first!
            var content = dict[action]! as! [String : Any]
            content["action"] = action
            print("### Sending \(content)")
            socket.emit("message", E.eventType, content)
        } catch let error {
            print("### Failed to serialize \(event): \(error)")
        }
    }

    init() {
        print("*** Initializing SocketIO")
        manager = SocketManager(socketURL: URL(string: "https://ostax.herokuapp.com/")!, config: [.log(true), .compress, .forceWebsockets(true)])
        socket = manager.defaultSocket

        socket.on(clientEvent: .connect) {data, ack in
            print("*** Socket connected")
        }
        
        socket.on(clientEvent: .disconnect) {data, ack in
            print("*** Socket disconnected")
        }
        
        socket.on(clientEvent: .error) {data, ack in
            print("*** Socket error")
        }

        socket.on("message") {[unowned self] data, ack in
            let kind = data[0] as! String
            let body = data[1] as! Dictionary<String, Any>
            
            switch (kind) {
            
            case "auth-response":
                handleEvent(body) { (event: AuthResponse) in
                    switch (event) {
                        case .Challenge:
                            print("### Auth challenge")
                            if let sessionToken = sessionToken {
                                print("### Sending session token \(sessionToken)")
                                sendEvent(AuthRequest.TokenLogin(sessionToken: sessionToken))
                            }
                        case .EmailLoginResponse(success: let success):
                            if (success) {
                                print("Email code sent")
                            } else {
                                print("Email code send failed")
                            }
                        case .EmailCodeResponse(success: let success, sessionToken: let newSessionToken):
                            if (success) {
                                print("Email code response: success")
                                self.sessionToken = newSessionToken!
                                self.loggedIn = true
                            } else {
                                print("Email code response: failed")
                            }
                        case .TokenLoginResponse(success: let success):
                            if (success) {
                                print("Token login response: success")
                                self.loggedIn = true
                            } else {
                                print("Token login response: failed")
                            }
                    }
                }
            case "app-event":
                handleEvent(body, appEvents.send(_:))
            default:
                print("Ignoring message")
            }
        }
        
        socket.connect()
    }
    
    func handleEvent<E: Decodable>(_ body: [String : Any], _ handler: (E) -> ()) {
        do {
            handler(try decodeEvent(body))
        } catch let error {
            print("Error decoding event \(body): \(error)")
        }
    }
    
    func decodeEvent<E: Decodable>(_ body: [String : Any]) throws -> E {
        let action = body["action"] as! String
        let withNestedStructure = [
            action: body
        ]
        let data = try JSONSerialization.data(withJSONObject: withNestedStructure, options: .prettyPrinted)
        let event: E = try JSONDecoder().decode(E.self, from: data)
        return event
    }
}
