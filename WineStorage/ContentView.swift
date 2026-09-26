//
//  ContentView.swift
//  WineStorage
//
//  Created by Christa Porter on 8/29/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            NavigationStack {
                StorageListView()
            }
            .tabItem {
                Label("Storage", systemImage: "wineglass")
            }

            NavigationStack {
                InventoryListView()
            }
            .tabItem {
                Label("Inventory", systemImage: "list.bullet")
            }

            NavigationStack {
                BackupRestoreView()
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Storage.self, Bottle.self, Shelf.self], inMemory: true)
}
