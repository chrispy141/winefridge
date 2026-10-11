//
//  InventoryListView.swift
//  WineStorage
//

import SwiftUI
import SwiftData
import UIKit

struct InventoryListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Storage.position) private var storages: [Storage]
    @Query(sort: \Bottle.name) private var bottles: [Bottle]
    @Query private var shelves: [Shelf]
    @State private var searchText = ""
    @State private var selectedBottle: Bottle?
    @State private var isAddingBottle = false
    @State private var outlookYears: Int

    /// Years-from-now options offered in the outlook selector, in 5-year
    /// increments out to four decades.
    private static let outlookOptions = Array(stride(from: 5, through: 40, by: 5))

    init() {
        _outlookYears = State(initialValue: 10)
    }

    private var currentYear: Int {
        Calendar.current.component(.year, from: .now)
    }

    private var timelineHorizonYear: Int {
        currentYear + outlookYears
    }

    private var filteredBottles: [Bottle] {
        guard !searchText.isEmpty else { return bottles }
        return bottles.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.producer.localizedCaseInsensitiveContains(searchText) ||
            $0.region.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image("EmblemText")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 72)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)

            HStack(spacing: 12) {
                DrinkWindowLegendView()
                    .layoutPriority(1)
                Spacer()
                Picker("Outlook", selection: $outlookYears) {
                    ForEach(Self.outlookOptions, id: \.self) { years in
                        Text("+\(years) years").tag(years)
                    }
                }
                .labelsHidden()
                .pickerStyle(.wheel)
                .frame(width: 130, height: 80)
                .clipped()
            }
            .padding(.horizontal)
            .padding(.top, 4)

            DrinkWindowAxisView(startYear: currentYear, endYear: timelineHorizonYear)
                .padding(.horizontal)
                .padding(.top, 8)

            List {
                ForEach(filteredBottles) { bottle in
                    Button {
                        selectedBottle = bottle
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            BottleRowLabel(bottle: bottle)
                            Text(locationDescription(for: bottle))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            DrinkWindowTimelineView(bottle: bottle, horizonYear: timelineHorizonYear)
                        }
                    }
                }
                .onDelete(perform: delete)
            }
            .searchable(text: $searchText, prompt: "Search bottles")
            .overlay {
                if bottles.isEmpty {
                    ContentUnavailableView(
                        "No Bottles Yet",
                        systemImage: "wineglass",
                        description: Text("Tap + to add a bottle.")
                    )
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Color.clear.frame(height: 12)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    isAddingBottle = true
                } label: {
                    Label("Add Bottle", systemImage: "plus")
                }
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

    /// A bottle has no storage unit of its own — its storage unit (if any)
    /// is derived from whichever shelf it's currently placed on. Unplaced
    /// bottles are shared, storage-agnostic inventory.
    private func locationDescription(for bottle: Bottle) -> String {
        guard let slot = bottle.slot, let shelf = shelves.first(where: { $0.shelfID == slot.shelfID }) else {
            return "Unassigned"
        }
        let storageName = storages.first(where: { $0.storageID == shelf.storageID })?.name ?? "Wine Storage"
        let storageShelves = shelves.filter { $0.storageID == shelf.storageID }
        return "\(storageName) — \(SlotID.locationDescription(for: slot, shelves: storageShelves))"
    }
}

#Preview {
    NavigationStack {
        InventoryListView()
    }
    .modelContainer(for: [Storage.self, Bottle.self, Shelf.self], inMemory: true)
}
