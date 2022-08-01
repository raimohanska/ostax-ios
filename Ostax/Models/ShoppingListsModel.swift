import Foundation
import Combine
import CoreData

enum EventSource: String {
    case local = "local", remote = "remote"
}

struct StoredEventWrapper {
    let appEvent: AppEvent
    let source: EventSource
    let timestamp: Date
}

enum SyncStatus {
    case Offline, SendingStoredEvents, Online
}

class ShoppingListsModel: ObservableObject {
    @Published var lists: [ShoppingList] = []
    @Published var syncStatus: SyncStatus = .Offline
    private let connection: SocketIOConnection
    private var bag = Set<AnyCancellable>()
    private var storedOfflineEvents: [StoredEventWrapper] = []

    // TODO: consider concurrency more carefully
    init(connection: SocketIOConnection) {
        self.connection = connection
        bag.insert(connection.appEvents.sink(receiveValue: { [self] event in
            //print("Received app event \(event)")
            applyEvent(event)
            _ = storeEvent(event, source: .remote)
            switch (event, syncStatus) {
            case (.ListsInit(_), .Offline):
                startSync()
            default: ()
            }
        }))
        
        bag.insert(connection.connected.filter { $0 == false }.sink { [self] _ in
            // disconnected
            syncStatus = .Offline
        })
        let storedEvents = readStoredEvents()
        storedOfflineEvents = storedEvents.filter { $0.source == .local }
        let remoteEvents = storedEvents.filter { $0.source == .remote }
        let initialLists: [ShoppingList] = []
        self.lists = remoteEvents.map { $0.appEvent }.reduce(initialLists, {
            lists, event in
            ShoppingListsModel.applySingleEvent(lists, event, localOfflineEvents: storedOfflineEvents)
        })
    }
    
    private func startSync() {
        syncStatus = .SendingStoredEvents
        print("Sending stored offline events: \(storedOfflineEvents.count)")
        storedOfflineEvents.forEach(sendStoredEvent(_:))
        checkSyncCompletion()
    }
    
    private func checkSyncCompletion() {
        if (storedOfflineEvents.count == 0) {
            syncStatus = .Online
        }
    }
    
    
    private static func getInitialLists(_ listsInit: [ShoppingList], _ localOfflineEvents: [StoredEventWrapper]) -> [ShoppingList] {
        return localOfflineEvents.reduce(listsInit, { lists, event in
            applySingleEvent(lists, event.appEvent, localOfflineEvents: nil)
        })
    }
        
    func dispatch(_ event: AppEvent) {
        print("Dispatching \(event)")
        if let wrapper = storeEvent(event, source: .local) {
            if syncStatus == .Online {
                sendStoredEvent(wrapper)
            }
            applyEvent(event)
        } else {
            fatalError("Failed to store event \(event) locally")
        }
    }
    
    private func sendStoredEvent(_ event: StoredEventWrapper) {
        connection.sendEvent(event.appEvent) { [self] in
            print("Got ack")
            let predicate = NSPredicate(format: "source == 'local' AND timestamp == %@", event.timestamp as NSDate)
            forEachStoredEvent(predicate, operation: { event, context in event.source = "remote" }, expectedCount: 1)
            storedOfflineEvents = storedOfflineEvents.filter { $0.timestamp != event.timestamp }
            checkSyncCompletion()
        }
    }
    
    static func applySingleEvent(_ lists: [ShoppingList], _ event: AppEvent, localOfflineEvents: [StoredEventWrapper]?) -> [ShoppingList] {
        switch (event) {
        case .AddItem(listId: let listId, item: let newItem):
            return modifyListItems(listId, fn: { $0 + [newItem] })
        case .DeleteItem(listId: let listId, itemId: let itemId):
            return modifyListItems(listId, fn: { $0.filter { $0.id != itemId } })
        case .ListsInit(lists: let lists):
            if let localOfflineEvents = localOfflineEvents {
                print("Lists received \(lists.map { $0.name })")
                print("Using \(localOfflineEvents.count) local events on top")
                return getInitialLists(lists, localOfflineEvents)
            } else {
                fatalError("ListsInit not supposed to be handled by applySingleEvent without localOfflineEvents")
            }
        default:
            print("Ignoring AppEvent \(event) for now")
            return lists
        }
        
        func modifyListItems(_ listId: String, fn: ([ShoppingItem]) -> [ShoppingItem]) -> [ShoppingList] {
            return lists.map { list in
                list.id == listId ? ShoppingList(id: list.id, name: list.name, items: fn(list.items)) : list
            }
        }
    }

    
    private func applyEvent(_ event: AppEvent) {
        self.lists = ShoppingListsModel.applySingleEvent(self.lists, event, localOfflineEvents: storedOfflineEvents)
    }

    static let ALL_REMOTE_EVENTS = NSPredicate(format: "source == 'remote'")
    static let ALL_EVENTS: NSPredicate? = nil
    
    private func deleteStoredEvents(_ predicate: NSPredicate?, expectedCount: Int? = nil) {
        forEachStoredEvent(predicate, operation: { $1.delete($0) }, expectedCount: expectedCount)
    }
    
    private func forEachStoredEvent(_ predicate: NSPredicate?, operation: (StoredAppEvent, NSManagedObjectContext) -> (), expectedCount: Int? = nil) {
        do {
            let context = persistentContainer.viewContext
            let request = NSFetchRequest<StoredAppEvent>(entityName: "StoredAppEvent")
            request.predicate = predicate
            request.includesPropertyValues = false
            // Perform the fetch request
            let objects = try context.fetch(request)
            
            if let expectedCount = expectedCount {
                if (objects.count != expectedCount) {
                    fatalError("Event count mismatch in delete. Expected \(expectedCount), found \(objects.count)")
                }
            }
                
            objects.forEach({ object in operation(object, context) })

            // Save the deletions to the persistent store
            try context.save()
            print("Deleted \(objects.count) stored events")
        } catch let error {
            print("### Failed deleting \(error)")
        }
    }

    
    private func storeEvent(_ event: AppEvent, source: EventSource) -> StoredEventWrapper? {
        switch (event) {
        case .ListsInit(lists: _): deleteStoredEvents(ShoppingListsModel.ALL_REMOTE_EVENTS)
        default: ()
        }
        do {
            let content = eventToDict(event)
            let storedEvent = StoredAppEvent(context: persistentContainer.viewContext)
            let action = content["action"]! as! String
            let timestamp = Date()
            storedEvent.action = action
            storedEvent.timestamp = timestamp
            storedEvent.source = source.rawValue
            let jsonData = try JSONSerialization.data(withJSONObject: content)
            storedEvent.json = String(data: jsonData, encoding: .utf8)
            try persistentContainer.viewContext.save()
            let wrapper = StoredEventWrapper(appEvent: event, source: source, timestamp: timestamp)
            if (source == .local) {
                storedOfflineEvents.append(wrapper)
            }
            //print("### Stored event")
            return wrapper
        } catch let error {
            print("### Failed saving \(error)")
            return nil
        }
    }
    
    private func readStoredEvents() -> [StoredEventWrapper] {
        do {
            let request = NSFetchRequest<StoredAppEvent>(entityName: "StoredAppEvent")
            let result = try persistentContainer.viewContext.fetch(request)
            print("### Read stored events \(result.map{ "\($0.action!) (\($0.source!))" })")
            return result.compactMap(parseStoredEvent(_:))
        } catch let error {
            print("### Failed loading events \(error)")
            return []
        }
    }
    
    private func parseStoredEvent(_ storedEvent: StoredAppEvent) -> StoredEventWrapper? {
        let json = storedEvent.json!
        do {
            let dict = try JSONSerialization.jsonObject(with: json.data(using: .utf8)!)
            let event: AppEvent = try eventFromDict(dict as! [String: Any])
            let source: EventSource = storedEvent.source.map({ EventSource(rawValue: $0) ?? .remote }) ?? .remote
            return StoredEventWrapper(appEvent: event, source: source, timestamp: storedEvent.timestamp!)
        } catch let error {
            print("### Failed decoding event \(json) : \(error)")
            return nil
        }
    }
    
    private lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "Model")
        container.loadPersistentStores { description, error in
            if let error = error {
                fatalError("Unable to load persistent stores: \(error)")
            }
        }
        return container
    }()
}

