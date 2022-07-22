import SwiftUI

@main
struct TestApp: App {
    @ObservedObject var connection: SocketIOConnection
    @ObservedObject var listModel: ShoppingListsModel
    
    init() {
        let newConnection: SocketIOConnection = .init()
        connection = newConnection
        listModel = .init(connection: newConnection)
    }

    var body: some Scene {
        WindowGroup {
            if connection.sessionToken != nil {
                ShoppingListsView(lists: listModel.lists, dispatch: listModel.dispatch(_:))
            } else {
                LoginView(loginController: connection)
            }
        }
    }
}
