//
//  StorageView.swift
//  WineStorage
//

import SwiftUI
import SwiftData

struct StorageView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var storage: Storage
    @Query private var shelves: [Shelf]
    /// All bottles, unfiltered — a bottle has no storage unit of its own, so
    /// the bottles that belong on this storage unit's shelves are derived
    /// from which shelf (if any) each bottle is placed on, not a stored
    /// storage id.
    @Query private var allBottles: [Bottle]
    @State private var selectedBottle: Bottle?
    @State private var newBottleSlot: SlotID?
    @State private var isShowingEditStorage = false
    @AppStorage("bottleZoomLevel") private var zoomLevel: Double = 1.0

    private let zoomRange: ClosedRange<Double> = 0.6...1.8
    private let zoomStep: Double = 0.2

    init(storage: Storage) {
        self.storage = storage
        let storageID = storage.storageID
        _shelves = Query(filter: #Predicate<Shelf> { $0.storageID == storageID }, sort: \Shelf.position)
    }

    private var displayName: String {
        storage.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Wine Storage" : storage.name
    }

    private var bottlesBySlot: [SlotID: Bottle] {
        let shelfIDs = Set(shelves.map(\.shelfID))
        return Dictionary(uniqueKeysWithValues: allBottles.compactMap { bottle in
            guard let slot = bottle.slot, shelfIDs.contains(slot.shelfID) else { return nil }
            return (slot, bottle)
        })
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 30) {
                    ForEach(Array(shelves.enumerated()), id: \.element.persistentModelID) { index, shelf in
                        ShelfView(
                            shelf: shelf,
                            shelfNumber: index + 1,
                            bottlesBySlot: bottlesBySlot,
                            availableWidth: geometry.size.width - 32,
                            zoomLevel: zoomLevel,
                            onSelectSlot: handleSelect,
                            onMoveBottle: handleMove
                        )
                    }
                }
                .padding()
            }
        }
        .navigationTitle(displayName)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ControlGroup {
                    Button {
                        zoomLevel = max(zoomRange.lowerBound, zoomLevel - zoomStep)
                    } label: {
                        Label("Zoom Out", systemImage: "minus.magnifyingglass")
                    }
                    .disabled(zoomLevel <= zoomRange.lowerBound)

                    Button {
                        zoomLevel = min(zoomRange.upperBound, zoomLevel + zoomStep)
                    } label: {
                        Label("Zoom In", systemImage: "plus.magnifyingglass")
                    }
                    .disabled(zoomLevel >= zoomRange.upperBound)
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button("Edit Storage") { isShowingEditStorage = true }
            }
        }
        .sheet(item: $selectedBottle) { bottle in
            BottleDetailView(bottle: bottle)
        }
        .sheet(item: $newBottleSlot) { slot in
            SlotPickerView(slot: slot)
        }
        .sheet(isPresented: $isShowingEditStorage) {
            EditStorageView(storage: storage)
        }
        .task {
            if shelves.isEmpty {
                Shelf.seedDefaults(in: modelContext, storageID: storage.storageID)
            }
        }
    }

    private func handleSelect(_ slot: SlotID) {
        if let bottle = bottlesBySlot[slot] {
            selectedBottle = bottle
        } else {
            newBottleSlot = slot
        }
    }

    /// Moves the bottle at `source` into `destination`. If `destination` is
    /// already occupied, the two bottles swap places.
    private func handleMove(_ source: SlotID, _ destination: SlotID) {
        guard source != destination, let sourceBottle = bottlesBySlot[source] else { return }
        if let destinationBottle = bottlesBySlot[destination] {
            destinationBottle.slot = source
        }
        sourceBottle.slot = destination
    }
}

#Preview {
    NavigationStack {
        StorageView(storage: Storage(name: "Wine Storage", position: 0))
    }
    .modelContainer(for: [Storage.self, Bottle.self, Shelf.self], inMemory: true)
}
