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
            switch (loginModel.state) {
            case .LoggedIn, .LoggingInWithToken:
                ShoppingListsView(lists: listModel.lists, syncStatus: listModel.syncStatus, dispatch: listModel.dispatch(_:))
            default:
                LoginView(loginModel: loginModel)
            }
        }
    }
}
