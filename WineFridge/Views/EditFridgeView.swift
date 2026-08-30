//
//  EditFridgeView.swift
//  WineFridge
//

import SwiftUI
import SwiftData

/// Lets the user add/remove shelves, resize each shelf's rows and slots, or
/// apply a common layout preset to a shelf.
struct EditFridgeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Shelf.position) private var shelves: [Shelf]
    @Query private var bottles: [Bottle]

    @State private var shelfPendingDeletion: Shelf?
    @AppStorage("fridgeName") private var fridgeName = "Wine Fridge"

    var body: some View {
        NavigationStack {
            List {
                Section("Name") {
                    TextField("Fridge Name", text: $fridgeName)
                }

                ForEach(Array(shelves.enumerated()), id: \.element.persistentModelID) { index, shelf in
                    ShelfEditRow(
                        shelf: shelf,
                        shelfNumber: index + 1,
                        onLayoutChange: { clearOutOfRangeBottles(for: shelf) }
                    )
                }
                .onMove(perform: moveShelves)
                .onDelete { offsets in
                    if let index = offsets.first {
                        shelfPendingDeletion = shelves[index]
                    }
                }

                Button {
                    addShelf()
                } label: {
                    Label("Add Shelf", systemImage: "plus")
                }
            }
            .navigationTitle("Edit Fridge")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    EditButton()
                }
            }
            .alert(
                "Remove Shelf?",
                isPresented: Binding(
                    get: { shelfPendingDeletion != nil },
                    set: { if !$0 { shelfPendingDeletion = nil } }
                ),
                presenting: shelfPendingDeletion
            ) { shelf in
                Button("Remove", role: .destructive) { delete(shelf) }
                Button("Cancel", role: .cancel) {}
            } message: { shelf in
                let count = bottles.filter { $0.slot?.shelfID == shelf.shelfID }.count
                if count > 0 {
                    Text("\(count) bottle\(count == 1 ? "" : "s") on this shelf will be unplaced.")
                } else {
                    Text("This shelf is empty.")
                }
            }
        }
    }

    private func addShelf() {
        modelContext.insert(Shelf(position: shelves.count, rowCount: 2, slotsPerRow: 4))
    }

    private func delete(_ shelf: Shelf) {
        for bottle in bottles where bottle.slot?.shelfID == shelf.shelfID {
            bottle.clearSlot()
        }
        modelContext.delete(shelf)
        renumberPositions()
        shelfPendingDeletion = nil
    }

    private func moveShelves(from source: IndexSet, to destination: Int) {
        var reordered = shelves
        reordered.move(fromOffsets: source, toOffset: destination)
        for (index, shelf) in reordered.enumerated() {
            shelf.position = index
        }
    }

    private func renumberPositions() {
        for (index, shelf) in shelves.enumerated() {
            shelf.position = index
        }
    }

    private func clearOutOfRangeBottles(for shelf: Shelf) {
        for bottle in bottles {
            guard let slot = bottle.slot, slot.shelfID == shelf.shelfID else { continue }
            if slot.row >= shelf.rowCount || slot.column >= shelf.slotsPerRow {
                bottle.clearSlot()
            }
        }
    }
}

private struct ShelfEditRow: View {
    @Bindable var shelf: Shelf
    let shelfNumber: Int
    let onLayoutChange: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Shelf \(shelfNumber)")
                .font(.headline)

            Picker("Rows", selection: $shelf.rowCount) {
                Text("1 Row").tag(1)
                Text("2 Rows").tag(2)
            }
            .pickerStyle(.segmented)
            .onChange(of: shelf.rowCount) { _, _ in onLayoutChange() }

            Stepper(
                "Slots per row: \(shelf.slotsPerRow)",
                value: $shelf.slotsPerRow,
                in: 2...8
            )
            .onChange(of: shelf.slotsPerRow) { _, _ in onLayoutChange() }

            Menu("Common Layouts") {
                ForEach(ShelfLayoutPreset.all) { preset in
                    Button(preset.name) {
                        shelf.rowCount = preset.rowCount
                        shelf.slotsPerRow = preset.slotsPerRow
                        onLayoutChange()
                    }
                }
            }
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    EditFridgeView()
        .modelContainer(for: [Bottle.self, Shelf.self], inMemory: true)
}
