//
//  StorageListView.swift
//  WineStorage
//

import SwiftUI
import SwiftData

/// The app's main page: lets the user pick which storage unit to open, and
/// create or delete storage units.
struct StorageListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Storage.position) private var storages: [Storage]

    @State private var isAddingStorage = false
    @State private var storagePendingDeletion: Storage?

    /// Storage units per row. Fixed (rather than an adaptive grid) so a
    /// partial row — including a single storage unit — is centered as a
    /// group instead of being pinned to the leading edge with empty trailing
    /// columns.
    private let storagesPerRow = 2

    private var rows: [[Storage]] {
        stride(from: 0, to: storages.count, by: storagesPerRow).map {
            Array(storages[$0..<min($0 + storagesPerRow, storages.count)])
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: 16) {
                        Spacer()
                        ForEach(row) { storage in
                            NavigationLink {
                                StorageView(storage: storage)
                            } label: {
                                StorageGridItem(storage: storage)
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    storagePendingDeletion = storage
                                }
                            }
                        }
                        Spacer()
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
        }
        .navigationTitle("Wine Storage")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isAddingStorage = true
                } label: {
                    Label("Add Storage", systemImage: "plus")
                }
            }
        }
        .overlay {
            if storages.isEmpty {
                ContentUnavailableView(
                    "No Storage Yet",
                    systemImage: "wineglass",
                    description: Text("Tap + to add wine storage.")
                )
            }
        }
        .sheet(isPresented: $isAddingStorage) {
            AddStorageView { name, icon in
                addStorage(name: name, icon: icon)
            }
        }
        .alert(
            "Delete Storage?",
            isPresented: Binding(
                get: { storagePendingDeletion != nil },
                set: { if !$0 { storagePendingDeletion = nil } }
            ),
            presenting: storagePendingDeletion
        ) { storage in
            Button("Delete", role: .destructive) { delete(storage) }
            Button("Cancel", role: .cancel) {}
        } message: { storage in
            Text("This will permanently delete \"\(storage.name)\" and all of its shelves and bottles.")
        }
    }

    private func addStorage(name: String, icon: FridgeIcon) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let storage = Storage(name: trimmed.isEmpty ? "Wine Storage" : trimmed, position: storages.count, icon: icon)
        modelContext.insert(storage)
    }

    private func delete(_ storage: Storage) {
        let storageID = storage.storageID
        let shelfDescriptor = FetchDescriptor<Shelf>(predicate: #Predicate { $0.storageID == storageID })
        let shelvesToDelete = (try? modelContext.fetch(shelfDescriptor)) ?? []
        let shelfIDs = Set(shelvesToDelete.map(\.shelfID))

        // A bottle has no storage unit of its own, so bottles "belonging" to
        // this storage unit are whichever ones are placed on one of its shelves.
        let allBottles = (try? modelContext.fetch(FetchDescriptor<Bottle>())) ?? []
        for bottle in allBottles where bottle.slot.map({ shelfIDs.contains($0.shelfID) }) == true {
            modelContext.delete(bottle)
        }
        for shelf in shelvesToDelete {
            modelContext.delete(shelf)
        }
        modelContext.delete(storage)
        renumberPositions()
        storagePendingDeletion = nil
    }

    private func renumberPositions() {
        for (index, storage) in storages.enumerated() {
            storage.position = index
        }
    }
}

/// A single grid cell: a large storage icon with its name in small text
/// below, matching the icon picker's visual style in `AddStorageView`.
private struct StorageGridItem: View {
    let storage: Storage

    var body: some View {
        VStack(spacing: 6) {
            Image(storage.displayIcon.imageName)
                .resizable()
                .scaledToFit()
                .frame(width: 144, height: 144)
                .padding(8)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color.secondary.opacity(0.3), lineWidth: 2)
                )
            Text(storage.name)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }
}

#Preview {
    NavigationStack {
        StorageListView()
    }
    .modelContainer(for: [Storage.self, Bottle.self, Shelf.self], inMemory: true)
}
