//
//  WineFridgeApp.swift
//  WineFridge
//
//  Created by Christa Porter on 8/29/26.
//

import SwiftUI
import SwiftData

@main
struct WineFridgeApp: App {
    let container: ModelContainer = {
        let configuration = ModelConfiguration(cloudKitDatabase: .none)
        return try! ModelContainer(for: Storage.self, Bottle.self, Shelf.self, configurations: configuration)
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
