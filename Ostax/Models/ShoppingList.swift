import Foundation

struct ShoppingItem: Codable, Identifiable {
    var id: String
    var name: String
}

struct ShoppingList: Codable, Identifiable {
    var id: String
    var name: String
    var items: [ShoppingItem]
}
