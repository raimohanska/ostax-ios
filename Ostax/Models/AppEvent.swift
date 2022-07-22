import Foundation

enum AppEvent {
    case ListsInit(lists: [ShoppingList])
    case SuggestionsUpdate
    case AddItem(listId: String, item: ShoppingItem)
    case DeleteItem(listId: String, itemId: String)
}


extension AppEvent: Codable, SendableEvent {
    static let eventType = "app-event"
    
    enum CodingKeys: String, CodingKey {
        case ListsInit = "lists.init"
        case SuggestionsUpdate = "suggestions.update"
        case AddItem = "item.add"
        case DeleteItem = "item.delete"
    }
}
