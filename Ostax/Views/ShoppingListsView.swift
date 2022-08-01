//
//  ShoppingListsView.swift
//  Test
//
//  Created by Juha Paananen on 20.7.2022.
//

import Foundation
import SwiftUI
import Combine

struct ShoppingListsView: View {
    var lists: [ShoppingList]
    let dispatch: Dispatch
    @Binding var connected: Bool
    
    var body: some View {
        VStack() {
            NavigationView {
                List {
                    ForEach(lists) { list in ShoppingListView(list: list, dispatch: dispatch) }
                }.toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Text("Ostax \(connected ? "🟢" : "🔴")")
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(action: {}) {
                            Label("Add List", systemImage: "plus")
                        }
                    }
                }
            }
        }
    }
}

struct ShoppingListsView_Previews: PreviewProvider {
    @State static var lists: [ShoppingList] = [
        ShoppingList(id: "1", name: "Groceries", items: [
            ShoppingItem(id: "1.1", name: "Bananas"),
            ShoppingItem(id: "1.2", name: "Cereals")
        ]),
        ShoppingList(id: "2", name: "Hardware", items: [
            ShoppingItem(id: "2.1", name: "Hammer"),
            ShoppingItem(id: "2.2", name: "Hammer drill"),
            ShoppingItem(id: "2.3", name: "Circle saw"),
        ])
    ]
    static var connected = CurrentValueSubject<Bool, Never>(true)
    static var previews: some View {
        Group {
            ShoppingListsView(lists: lists,
                              dispatch: { item in print(item)},
                              connected: connected.binding
            )
        }
    }
}
