//
//  BottleDetailView.swift
//  WineFridge
//

import SwiftUI
import SwiftData
import UIKit

struct BottleDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Shelf.position) private var shelves: [Shelf]
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
                    LabeledContent("Name", value: bottle.name)
                    if !bottle.producer.isEmpty {
                        LabeledContent("Producer", value: bottle.producer)
                    }
                    LabeledContent("Type", value: bottle.wineType.rawValue)
                    if let vintage = bottle.vintage {
                        LabeledContent("Vintage", value: String(vintage))
                    }
                    if !bottle.region.isEmpty {
                        LabeledContent("Region", value: bottle.region)
                    }
                    LabeledContent("Location", value: locationDescription)
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

    private var locationDescription: String {
        SlotID.locationDescription(for: bottle.slot, shelves: shelves)
    }
}
