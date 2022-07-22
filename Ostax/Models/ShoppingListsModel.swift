import Foundation
import Combine

class ShoppingListsModel: ObservableObject {
    @Published var lists: [ShoppingList] = []
    private let connection: SocketIOConnection
    private var cancelable: Cancellable?
    
    init(connection: SocketIOConnection) {
        self.connection = connection
        cancelable = connection.appEvents.sink(receiveValue: { [self] value in
            print("Processing app event")
            applyEvent(value)
        })
    }
        
    func dispatch(_ event: AppEvent) {
        print("Dispatching \(event)")
        connection.sendEvent(event)
        applyEvent(event)
    }
    
    func applyEvent(_ event: AppEvent) {
        switch (event) {
            case .AddItem(listId: let listId, item: let newItem):
                modifyListItems(listId, fn: { $0 + [newItem] })
            case .DeleteItem(listId: let listId, itemId: let itemId):
                modifyListItems(listId, fn: { $0.filter { $0.id != itemId } })
            case .ListsInit(lists: let lists):
                self.lists = lists
                print("Lists received \(lists)")
            default:
                print("Ignoring AppEvent \(event) for now")
        }
        
        func modifyListItems(_ listId: String, fn: ([ShoppingItem]) -> [ShoppingItem]) {
            lists = lists.map { list in
                list.id == listId ? ShoppingList(id: list.id, name: list.name, items: fn(list.items)) : list
            }
        }
    }
}

