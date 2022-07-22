import Foundation
import Combine
import CoreData

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
        let storedEvents = readStoredEvents()
        self.lists = getInitialLists(storedEvents)
    }
    
    func getInitialLists(_ events: [AppEvent]) -> [ShoppingList] {
        for e in events {
            switch (e) {
            case .ListsInit(lists: let lists):
                return lists
            default:
                ()
            }
        }
        return []
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
            clearStoredEvents()
            storeEvent(event)
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
    
    func clearStoredEvents() {
        do {
            let context = persistentContainer.viewContext
            let request = NSFetchRequest<StoredAppEvent>(entityName: "StoredAppEvent")
            request.predicate = NSPredicate(format: "action == 'lists.init'")
            request.includesPropertyValues = false
            // Perform the fetch request
            let objects = try context.fetch(request)
                
            // Delete the objects
            for object in objects {
                context.delete(object)
            }

            // Save the deletions to the persistent store
            try context.save()
        } catch let error {
            print("### Failed deleting \(error)")
        }
    }
    
    func storeEvent(_ event: AppEvent) {
        do {
            let content = eventToDict(event)
            let storedEvent = StoredAppEvent(context: persistentContainer.viewContext)
            let action = content["action"]! as! String
            storedEvent.action = action
            storedEvent.timestamp = Date()
            let jsonData = try JSONSerialization.data(withJSONObject: content)
            storedEvent.json = String(data: jsonData, encoding: .utf8)
            try persistentContainer.viewContext.save()
            print("### Stored event")
        } catch let error {
            print("### Failed saving \(error)")
        }
    }
    
    func readStoredEvents() -> [AppEvent] {
        do {
            let request = NSFetchRequest<StoredAppEvent>(entityName: "StoredAppEvent")
            let result = try persistentContainer.viewContext.fetch(request)
            print("### Read stored events, count=\(result.count)")
            return result.compactMap { storedEvent in
                let json = storedEvent.json!
                do {
                    let dict = try JSONSerialization.jsonObject(with: json.data(using: .utf8)!)
                    let event: AppEvent = try eventFromDict(dict as! [String: Any])
                    return event
                } catch let error {
                    print("### Failed decoding event \(json) : \(error)")
                    return nil
                }
            }
        } catch let error {
            print("### Failed loading events \(error)")
            return []
        }
    }
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "Model")
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Unable to load persistent stores: \(error)")
            }
        }
        return container
    }()
}

