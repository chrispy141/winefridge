//
//  ContentView.swift
//  WineStorage
//
//  Created by Christa Porter on 8/29/26.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var isShowingSettings = false

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
        }
        .overlay(alignment: .bottomTrailing) {
            Button {
                isShowingSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 44, height: 44)
            }
            .background(.bar, in: Circle())
            .shadow(radius: 2)
            .padding(.trailing, 16)
            .padding(.bottom, 16)
        }
        .sheet(isPresented: $isShowingSettings) {
            NavigationStack {
                BackupRestoreView()
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Storage.self, Bottle.self, Shelf.self], inMemory: true)
}
