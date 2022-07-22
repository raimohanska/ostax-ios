import Foundation
import SwiftUI

struct ShoppingListView: View {
    var list: ShoppingList
    let dispatch: Dispatch
    
    @State private var newItemName = ""
    @State private var selected: ShoppingItem?
    
    func addItem() {
        dispatch(.AddItem(
            listId: list.id, item: ShoppingItem(id: UUID().uuidString, name: newItemName)
        ))
        newItemName = ""
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            HStack() {
                Text("\(list.name) (\(list.items.count))").font(.title2)
                    .frame( maxWidth: .infinity, alignment: .leading)
            }.padding(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
            VStack(alignment: .leading) {
                ForEach(list.items) { item in
                    HStack {
                        Text(item.name)
                            .padding(EdgeInsets(top: 0, leading: 0, bottom: 2, trailing: 0))
                            .onTapGesture {
                                selected = item
                            }
                        if (selected == item) {
                            Button(action: { dispatch(.DeleteItem(listId: list.id, itemId: item.id)) }) {
                                Label("", systemImage: "trash")
                            }.frame(alignment: .trailing)
                        }
                    }
                }
                HStack() {
                    TextField("Add new item", text: $newItemName)
                        .onSubmit(addItem)
                        .padding(EdgeInsets(top: 4, leading: 0, bottom: 2, trailing: 0))

                    Button(action: addItem, label: { Image(systemName: "plus") })
                        .disabled(newItemName.isEmpty)
                        .frame(alignment: .trailing)
                }
            }.multilineTextAlignment(.leading)
        }
    }
}

struct ShoppingListView_Previews: PreviewProvider {
    @State static var list: ShoppingList =
        ShoppingList(id: "1", name: "Groceries", items: [
            ShoppingItem(id: "1.1", name: "Bananas"),
            ShoppingItem(id: "1.2", name: "Cereals")
        ])
    
    static var previews: some View {
        ShoppingListView(list: list, dispatch: { event in print(event)} )
        ShoppingListView(list: list, dispatch: { event in print(event)} )
            .previewLayout(.fixed(width: 568, height: 320))
    }
}
