//
//  FridgeView.swift
//  WineFridge
//

import SwiftUI
import SwiftData

struct FridgeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Shelf.position) private var shelves: [Shelf]
    @Query private var bottles: [Bottle]
    @State private var selectedBottle: Bottle?
    @State private var newBottleSlot: SlotID?
    @State private var isShowingEditFridge = false
    @AppStorage("fridgeName") private var fridgeName = "Wine Fridge"

    private var displayName: String {
        fridgeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Wine Fridge" : fridgeName
    }

    private var bottlesBySlot: [SlotID: Bottle] {
        Dictionary(uniqueKeysWithValues: bottles.compactMap { bottle in
            bottle.slot.map { ($0, bottle) }
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
                Button("Edit Fridge") { isShowingEditFridge = true }
            }
        }
        .sheet(item: $selectedBottle) { bottle in
            BottleDetailView(bottle: bottle)
        }
        .sheet(item: $newBottleSlot) { slot in
            SlotPickerView(slot: slot)
        }
        .sheet(isPresented: $isShowingEditFridge) {
            EditFridgeView()
        }
        .task {
            if shelves.isEmpty {
                Shelf.seedDefaults(in: modelContext)
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
        FridgeView()
    }
    .modelContainer(for: [Bottle.self, Shelf.self], inMemory: true)
}
