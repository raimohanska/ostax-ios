import SwiftUI
import Combine

@main
struct TestApp: App {
    @ObservedObject var loginModel: RemoteLoginModel
    @ObservedObject var listModel: ShoppingListsModel
    var connected: CurrentValueSubject<Bool, Never>
    
    init() {
        let newConnection: SocketIOConnection = .init()
        listModel = .init(connection: newConnection)
        loginModel = RemoteLoginModel.init(connection: newConnection)
        connected = newConnection.connected
    }

    var body: some Scene {
        WindowGroup {
            if loginModel.state == .LoggedIn {
                ShoppingListsView(lists: listModel.lists, dispatch: listModel.dispatch(_:), connected: connected.binding)
            } else {
                LoginView(loginModel: loginModel)
            }
        }
    }
}
