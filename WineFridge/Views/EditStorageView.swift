//
//  EditStorageView.swift
//  WineFridge
//

import SwiftUI
import SwiftData

/// Lets the user add/remove shelves, resize each shelf's rows and slots, or
/// apply a common layout preset to a shelf.
struct EditStorageView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var storage: Storage
    @Query private var shelves: [Shelf]
    @Query private var bottles: [Bottle]

    @State private var shelfPendingDeletion: Shelf?

    init(storage: Storage) {
        self.storage = storage
        let storageID = storage.storageID
        _shelves = Query(filter: #Predicate<Shelf> { $0.storageID == storageID }, sort: \Shelf.position)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Name") {
                    TextField("Storage Name", text: $storage.name)
                }

                Section("Icon") {
                    HStack(spacing: 16) {
                        ForEach(FridgeIcon.allCases) { candidate in
                            FridgeIconOption(icon: candidate, isSelected: storage.displayIcon == candidate) {
                                storage.icon = candidate
                            }
                        }
                        Spacer()
                    }
                }

                ForEach(Array(shelves.enumerated()), id: \.element.persistentModelID) { index, shelf in
                    ShelfEditRow(
                        shelf: shelf,
                        shelfNumber: index + 1,
                        otherShelves: shelves.enumerated()
                            .filter { $0.offset != index }
                            .map { (number: $0.offset + 1, shelf: $0.element) },
                        onLayoutChange: { clearOutOfRangeBottles(for: shelf) }
                    )
                }
                .onMove(perform: moveShelves)
                .onDelete { offsets in
                    if let index = offsets.first {
                        shelfPendingDeletion = shelves[index]
                    }
                }

                if shelves.isEmpty {
                    Button {
                        addShelf()
                    } label: {
                        Label("Add Shelf", systemImage: "plus")
                    }
                } else {
                    Menu {
                        Button {
                            addShelf()
                        } label: {
                            Label("Add Shelf", systemImage: "plus")
                        }
                        Button {
                            addShelf(identicalToLast: true)
                        } label: {
                            Label("Add Identical (Shelf \(shelves.count))", systemImage: "plus.square.on.square")
                        }
                    } label: {
                        Label("Add Shelf", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("Edit Storage")
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

    private func addShelf(identicalToLast: Bool = false) {
        let rowSlotCounts = identicalToLast ? (shelves.last?.rowSlotCounts ?? [4, 4]) : [4, 4]
        let isOffsetRows = identicalToLast ? (shelves.last?.isOffsetRows ?? true) : true
        modelContext.insert(Shelf(position: shelves.count, rowSlotCounts: rowSlotCounts, isOffsetRows: isOffsetRows, storageID: storage.storageID))
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
            if slot.row >= shelf.rowSlotCounts.count || slot.column >= shelf.rowSlotCounts[slot.row] {
                bottle.clearSlot()
            }
        }
    }
}

private struct ShelfEditRow: View {
    @Bindable var shelf: Shelf
    let shelfNumber: Int
    let otherShelves: [(number: Int, shelf: Shelf)]
    let onLayoutChange: () -> Void

    private let slotRange = 1...10

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Shelf \(shelfNumber)")
                    .font(.headline)
                Spacer()
                if !otherShelves.isEmpty {
                    Menu("Copy Shelf") {
                        ForEach(otherShelves, id: \.shelf.persistentModelID) { entry in
                            Button("Copy Shelf \(entry.number)") {
                                shelf.rowSlotCounts = entry.shelf.rowSlotCounts
                                shelf.isOffsetRows = entry.shelf.isOffsetRows
                                onLayoutChange()
                            }
                        }
                    }
                    .font(.subheadline)
                }
            }

            ForEach(Array(shelf.rowSlotCounts.enumerated()), id: \.offset) { rowIndex, count in
                HStack {
                    Stepper(
                        "Row \(rowIndex + 1): \(count) bottle\(count == 1 ? "" : "s")",
                        value: Binding(
                            get: { shelf.rowSlotCounts.indices.contains(rowIndex) ? shelf.rowSlotCounts[rowIndex] : count },
                            set: { newValue in
                                guard shelf.rowSlotCounts.indices.contains(rowIndex) else { return }
                                shelf.rowSlotCounts[rowIndex] = newValue
                                onLayoutChange()
                            }
                        ),
                        in: slotRange
                    )
                    if shelf.rowSlotCounts.count > 1 {
                        Button(role: .destructive) {
                            guard shelf.rowSlotCounts.indices.contains(rowIndex) else { return }
                            shelf.rowSlotCounts.remove(at: rowIndex)
                            onLayoutChange()
                        } label: {
                            Image(systemName: "minus.circle")
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack {
                Button {
                    shelf.rowSlotCounts.append(shelf.rowSlotCounts.last ?? 4)
                    onLayoutChange()
                } label: {
                    Label("Add Row", systemImage: "plus")
                }
                .font(.subheadline)

                Spacer()

                Menu("Common Layouts") {
                    ForEach(ShelfLayoutPreset.all) { preset in
                        Button(preset.name) {
                            shelf.rowSlotCounts = preset.rowSlotCounts
                            shelf.isOffsetRows = preset.isOffsetRows
                            onLayoutChange()
                        }
                    }
                }
                .font(.subheadline)
            }

            if shelf.rowSlotCounts.count > 1 {
                Toggle("Offset Rows", isOn: $shelf.isOffsetRows)
                    .font(.subheadline)
            }
        }
        .padding(.vertical, 6)
    }
}

#Preview {
    EditStorageView(storage: Storage(name: "Wine Storage", position: 0))
        .modelContainer(for: [Storage.self, Bottle.self, Shelf.self], inMemory: true)
}
