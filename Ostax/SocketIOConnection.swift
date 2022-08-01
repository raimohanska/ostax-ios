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

protocol SendableEvent: Encodable {
    static var eventType: String { get }
}

func eventToDict<E : SendableEvent>(_ event: E) -> [String: Any] {
    do {
        let initialDict = try event.asDictionary()
        precondition(initialDict.keys.count == 1)
        let action: String = initialDict.keys.first!
        var content = initialDict[action]! as! [String : Any]
        content["action"] = action
        return content
    } catch let error {
        fatalError("Failed to serialize \(event): \(error)")
    }
}

func eventFromDict<E: Decodable>(_ body: [String : Any]) throws -> E {
    let action = body["action"] as! String
    let withNestedStructure = [
        action: body
    ]
    let data = try JSONSerialization.data(withJSONObject: withNestedStructure, options: .prettyPrinted)
    let event: E = try JSONDecoder().decode(E.self, from: data)
    return event
}

extension Notification.Name {
    static let AppEvent = NSNotification.Name("AppEvent")
}

class SocketIOConnection: ObservableObject {
    private var manager: SocketManager!
    private var socket: SocketIOClient!
    let appEvents = PassthroughSubject<AppEvent, Never>()
    let authResponses = PassthroughSubject<AuthResponse, Never>()
    var connected = CurrentValueSubject<Bool, Never>(false)
    
    func sendEvent<E : SendableEvent>(_ event: E) {
        let content = eventToDict(event)
        print("### Sending \(content)")
        socket.emit("message", E.eventType, content)
        //NotificationCenter.default.publisher(for: .AppEvent).sink(receiveValue: { print($0)})
    }
    
    init() {
        connect()
    }
    
    private func reconnect() {
        connected.send(false)
        print("### Reconnecting...")
        connect()
    }

    private func connect() {
        print("*** Initializing SocketIO")
        let serverUrl = ProcessInfo.processInfo.environment["SERVER_URL"] ?? "https://ostax.herokuapp.com/"
        manager = SocketManager(socketURL: URL(string: serverUrl)!, config: [
            .log(false),
            .compress,
            .forceWebsockets(true),
            .reconnects(true)
        ])
        print("*** Manager up")
        socket = manager.defaultSocket
        print("*** Socket up")
        
        socket.on(clientEvent: .connect) {[unowned self] data, ack in
            print("*** Socket connected")
            connected.send(true)
        }
        
        socket.on(clientEvent: .disconnect) {[unowned self] data, ack in
            print("*** Socket disconnected")
            reconnect()
        }
        
        socket.on(clientEvent: .error) {[unowned self] data, ack in
            print("*** Socket error")
            reconnect()
        }
        
        socket.on(clientEvent: .statusChange) { [unowned self] data, ack in
            print("*** Status change: \(socket.status)")
        }
        
        socket.on("message") {[unowned self] data, ack in
            let kind = data[0] as! String
            let body = data[1] as! Dictionary<String, Any>
            
            switch (kind) {
            case "auth-response":
                handleEvent(body, authResponses.send(_:))
            case "app-event":
                handleEvent(body, appEvents.send(_:))
            default:
                print("Ignoring message")
            }
        }
        
        print("*** Socket connecting with handler...")
        socket.connect(
            withPayload: nil,
            timeoutAfter: 5 /* seconds */,
            withHandler: {[self] in
                print("*** Failed to connect")
                reconnect()
            })
        print("*** Socket connecting done")
    }
    
    func handleEvent<E: Decodable>(_ body: [String : Any], _ handler: (E) -> ()) {
        do {
            handler(try eventFromDict(body))
        } catch let error {
            print("Error decoding event \(body): \(error)")
        }
    }
}
