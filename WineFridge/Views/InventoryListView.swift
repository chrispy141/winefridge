//
//  InventoryListView.swift
//  WineFridge
//

import SwiftUI
import SwiftData
import UIKit

struct InventoryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Bottle.name) private var bottles: [Bottle]
    @Query(sort: \Shelf.position) private var shelves: [Shelf]
    @State private var searchText = ""
    @State private var selectedBottle: Bottle?
    @State private var isAddingBottle = false

    private var filteredBottles: [Bottle] {
        guard !searchText.isEmpty else { return bottles }
        return bottles.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.producer.localizedCaseInsensitiveContains(searchText) ||
            $0.region.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List {
            ForEach(filteredBottles) { bottle in
                Button {
                    selectedBottle = bottle
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        BottleRowLabel(bottle: bottle)
                        Text(locationDescription(for: bottle))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete(perform: delete)
        }
        .searchable(text: $searchText, prompt: "Search bottles")
        .navigationTitle("Inventory")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isAddingBottle = true
                } label: {
                    Label("Add Bottle", systemImage: "plus")
                }
            }
        }
        .overlay {
            if bottles.isEmpty {
                ContentUnavailableView(
                    "No Bottles Yet",
                    systemImage: "wineglass",
                    description: Text("Tap + to add a bottle.")
                )
            }
        }
        .sheet(item: $selectedBottle) { bottle in
            BottleDetailView(bottle: bottle)
        }
        .sheet(isPresented: $isAddingBottle) {
            BottleFormView()
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(filteredBottles[index])
        }
    }

    private func locationDescription(for bottle: Bottle) -> String {
        SlotID.locationDescription(for: bottle.slot, shelves: shelves)
    }
}
