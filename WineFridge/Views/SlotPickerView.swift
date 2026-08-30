//
//  SlotPickerView.swift
//  WineFridge
//

import SwiftUI
import SwiftData
import UIKit

/// Presented when tapping an empty shelf slot. Lets the user either place an
/// existing unplaced bottle from inventory into the slot, or create a new one.
struct SlotPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var bottles: [Bottle]

    let slot: SlotID

    @State private var searchText = ""
    @State private var isAddingNewBottle = false

    private var unplacedBottles: [Bottle] {
        let unplaced = bottles.filter { $0.slot == nil }
        guard !searchText.isEmpty else { return unplaced }
        return unplaced.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.producer.localizedCaseInsensitiveContains(searchText) ||
            $0.region.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        isAddingNewBottle = true
                    } label: {
                        Label("Add New Bottle", systemImage: "plus")
                    }
                }
                if !unplacedBottles.isEmpty {
                    Section("From Inventory") {
                        ForEach(unplacedBottles) { bottle in
                            Button {
                                bottle.slot = slot
                                dismiss()
                            } label: {
                                BottleRowLabel(bottle: bottle)
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search inventory")
            .navigationTitle("Add Bottle")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $isAddingNewBottle, onDismiss: { dismiss() }) {
                BottleFormView(newBottleSlot: slot)
            }
        }
    }
}

/// The row layout shared by `SlotPickerView` and `InventoryListView`.
struct BottleRowLabel: View {
    let bottle: Bottle

    var body: some View {
        HStack {
            if let photoData = bottle.photoData, let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 32, height: 32)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(bottle.wineType.color)
                    .frame(width: 12, height: 12)
            }
            VStack(alignment: .leading) {
                Text(bottle.name)
                    .foregroundStyle(.primary)
                if !bottle.producer.isEmpty {
                    Text(bottle.producer)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let vintage = bottle.vintage {
                Text(String(vintage))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
