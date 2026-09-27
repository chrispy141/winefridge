//
//  BottleDetailView.swift
//  WineStorage
//

import SwiftUI
import SwiftData
import UIKit

struct BottleDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var shelves: [Shelf]
    @Query private var storages: [Storage]
    let bottle: Bottle
    @State private var isEditing = false

    var body: some View {
        NavigationStack {
            List {
                if let photoData = bottle.photoData, let uiImage = UIImage(data: photoData) {
                    Section {
                        HStack {
                            Spacer()
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxHeight: 220)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            Spacer()
                        }
                        .listRowBackground(Color.clear)
                    }
                }
                Section("Wine") {
                    if !bottle.producer.isEmpty {
                        LabeledContent("Producer", value: bottle.producer)
                    }
                    LabeledContent("Wine / Cuvée", value: bottle.name)
                    if !bottle.varietal.isEmpty {
                        LabeledContent("Varietal / Blend", value: bottle.varietal)
                    }
                    LabeledContent("Style", value: bottle.wineType.rawValue)
                    if let vintage = bottle.vintage {
                        LabeledContent("Vintage", value: String(vintage))
                    }
                    LabeledContent("Storage", value: storageName)
                    LabeledContent("Location", value: locationDescription)
                }
                if !bottle.country.isEmpty || !bottle.region.isEmpty || !bottle.appellation.isEmpty || !bottle.vineyard.isEmpty || !bottle.designation.isEmpty {
                    Section("Origin") {
                        if !bottle.country.isEmpty {
                            LabeledContent("Country", value: bottle.country)
                        }
                        if !bottle.region.isEmpty {
                            LabeledContent("Region", value: bottle.region)
                        }
                        if !bottle.appellation.isEmpty {
                            LabeledContent("Appellation", value: bottle.appellation)
                        }
                        if !bottle.vineyard.isEmpty {
                            LabeledContent("Vineyard", value: bottle.vineyard)
                        }
                        if !bottle.designation.isEmpty {
                            LabeledContent("Designation / Tier", value: bottle.designation)
                        }
                    }
                }
                Section("Bottle") {
                    LabeledContent("Bottle Size", value: bottle.bottleSize.rawValue)
                    if let abv = bottle.abv {
                        LabeledContent("ABV", value: "\(abv)%")
                    }
                }
                if !bottle.notes.isEmpty {
                    Section("Notes") {
                        Text(bottle.notes)
                    }
                }
                Section {
                    if bottle.slot != nil {
                        Button("Remove from Shelf", role: .destructive) {
                            bottle.clearSlot()
                            dismiss()
                        }
                    }
                    Button("Delete Bottle", role: .destructive) {
                        modelContext.delete(bottle)
                        dismiss()
                    }
                }
            }
            .navigationTitle(bottle.name)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit") { isEditing = true }
                }
            }
            .sheet(isPresented: $isEditing) {
                BottleFormView(editing: bottle)
            }
        }
    }

    /// A bottle has no storage unit of its own — its storage unit (if any) is
    /// derived from whichever shelf it's currently placed on.
    private var placedShelf: Shelf? {
        guard let slot = bottle.slot else { return nil }
        return shelves.first(where: { $0.shelfID == slot.shelfID })
    }

    private var storageName: String {
        guard let placedShelf else { return "Unassigned" }
        return storages.first(where: { $0.storageID == placedShelf.storageID })?.name ?? "Wine Storage"
    }

    private var locationDescription: String {
        guard let placedShelf else { return "Unassigned" }
        let storageShelves = shelves.filter { $0.storageID == placedShelf.storageID }
        return SlotID.locationDescription(for: bottle.slot, shelves: storageShelves)
    }
}
