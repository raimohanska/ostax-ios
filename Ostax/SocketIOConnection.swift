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
        socket.emit("message", "auth-request", [
            "action": "email-login",
            "email": email
        ])
    }
    
    func codeLogin(email: String, code: String) {
        socket.emit("message", "auth-request", [
            "action": "email-code-validation",
            "email": email,
            "code": code
        ])
    }

    
    func sendEvent(_ event: AppEvent) {
        do {
            let dict = try event.asDictionary()
            precondition(dict.keys.count == 1)
            let action: String = dict.keys.first!
            var content = dict[action]! as! [String : Any]
            content["action"] = action
            print("### Sending \(content)")
            socket.emit("message", "app-event", content)
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
            let action = body["action"] as! String
            switch (kind, action) {
            case ("auth-response", "challenge"):
                print("### Auth challenge")
                if sessionToken != nil {
                    print("### Sending session token \(sessionToken)")
                    socket.emit("message", "auth-request", [
                        "action": "token-login",
                        "sessionToken": sessionToken
                    ])
                }
            case ("auth-response", "email-code-response"):
                let success = body["success"] as! Bool
                if (success) {
                    print("Email code response: success")
                    self.sessionToken = body["sessionToken"] as! String
                    self.loggedIn = true
                    print("sessionToken: \(sessionToken)")
                } else {
                    print("Email code response: failed")
                }
            case ("auth-response", "token-login-response"):
                let success = body["success"] as! Bool
                if (success) {
                    print("Token login response: success")
                    self.loggedIn = true
                } else {
                    print("Token login response: failed")
                }
            case ("app-event", _):
                let withNestedStructure = [
                    action: body
                ]
                do {
                    // Funny conversion to JSON data first before decode
                    let data = try JSONSerialization.data(withJSONObject: withNestedStructure, options: .prettyPrinted)
                    let appEvent: AppEvent = try JSONDecoder().decode(AppEvent.self, from: data)
                    appEvents.send(appEvent)
                } catch let error {
                    print("Error decoding App event \(withNestedStructure): \(error)")
                }
            default:
                print("Ignoring message")
            }
        }
        
        socket.connect()
    }
}
