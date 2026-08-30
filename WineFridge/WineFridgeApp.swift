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
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [Bottle.self, Shelf.self])
    }
}
