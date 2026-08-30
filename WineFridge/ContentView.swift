//
//  ContentView.swift
//  WineFridge
//
//  Created by Christa Porter on 8/29/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            NavigationStack {
                FridgeView()
            }
            .tabItem {
                Label("Fridge", systemImage: "wineglass")
            }

            NavigationStack {
                InventoryListView()
            }
            .tabItem {
                Label("Inventory", systemImage: "list.bullet")
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Bottle.self, Shelf.self], inMemory: true)
}
