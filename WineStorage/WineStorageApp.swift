//
//  WineStorageApp.swift
//  WineStorage
//
//  Created by Christa Porter on 8/29/26.
//

import SwiftUI
import SwiftData

@main
struct WineStorageApp: App {
    let container: ModelContainer = {
        let configuration = ModelConfiguration(cloudKitDatabase: .automatic)
        return try! ModelContainer(for: Storage.self, Bottle.self, Shelf.self, configurations: configuration)
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
