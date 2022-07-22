import SwiftUI

@main
struct TestApp: App {
    @ObservedObject var loginModel: RemoteLoginModel
    @ObservedObject var listModel: ShoppingListsModel
    
    init() {
        let newConnection: SocketIOConnection = .init()
        listModel = .init(connection: newConnection)
        loginModel = RemoteLoginModel.init(connection: newConnection)
    }

    var body: some Scene {
        WindowGroup {
            if loginModel.state == .LoggedIn {
                ShoppingListsView(lists: listModel.lists, dispatch: listModel.dispatch(_:))
            } else {
                LoginView(loginModel: loginModel)
            }
        }
    }
}
