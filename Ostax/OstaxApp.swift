import SwiftUI

@main
struct TestApp: App {
    @ObservedObject var socket: SocketIOConnection = .init()
    
    var body: some Scene {
        WindowGroup {
            if socket.sessionToken != nil {
                ShoppingListsView(lists: socket.lists, dispatch: socket.dispatch(_:))
            } else {
                LoginView(loginController: socket)
            }
        }
    }
}
