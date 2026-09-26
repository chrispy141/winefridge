//
//  BottleFormView.swift
//  WineStorage
//

import SwiftUI
import SwiftData
import PhotosUI
import UIKit

/// Add or edit a bottle. Use `init(newBottleSlot:)` to create a bottle — pass
/// a slot to place it directly on a shelf, or `nil` to leave it unplaced in
/// the shared, storage-agnostic inventory — or `init(editing:)` to edit an
/// existing bottle in place.
struct BottleFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var bottles: [Bottle]

    private let existingBottle: Bottle?
    private let slotForNewBottle: SlotID?

    @State private var name: String
    @State private var producer: String
    @State private var wineType: WineType
    @State private var vintageText: String
    @State private var region: String
    @State private var notes: String
    @State private var photoData: Data?
    @State private var photosPickerItem: PhotosPickerItem?
    @State private var isShowingCamera = false

    init(newBottleSlot slot: SlotID? = nil) {
        existingBottle = nil
        slotForNewBottle = slot
        _name = State(initialValue: "")
        _producer = State(initialValue: "")
        _wineType = State(initialValue: .red)
        _vintageText = State(initialValue: "")
        _region = State(initialValue: "")
        _notes = State(initialValue: "")
        _photoData = State(initialValue: nil)
    }

    init(editing bottle: Bottle) {
        existingBottle = bottle
        slotForNewBottle = nil
        _name = State(initialValue: bottle.name)
        _producer = State(initialValue: bottle.producer)
        _wineType = State(initialValue: bottle.wineType)
        _vintageText = State(initialValue: bottle.vintage.map(String.init) ?? "")
        _region = State(initialValue: bottle.region)
        _notes = State(initialValue: bottle.notes)
        _photoData = State(initialValue: bottle.photoData)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Photo") {
                    if let currentPhotoData = photoData, let uiImage = UIImage(data: currentPhotoData) {
                        HStack {
                            Spacer()
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 160)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            Spacer()
                        }
                        Button("Remove Photo", role: .destructive) {
                            photoData = nil
                            photosPickerItem = nil
                        }
                    }
                    PhotosPicker(selection: $photosPickerItem, matching: .images) {
                        Label("Choose Photo", systemImage: "photo.on.rectangle")
                    }
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Button {
                            isShowingCamera = true
                        } label: {
                            Label("Take Photo", systemImage: "camera")
                        }
                    }
                }
                Section("Wine") {
                    AutocompleteTextField(label: "Name", text: $name, suggestions: pastValues(\.name))
                    AutocompleteTextField(label: "Producer", text: $producer, suggestions: pastValues(\.producer))
                    Picker("Type", selection: $wineType) {
                        ForEach(WineType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    TextField("Vintage", text: $vintageText)
                        .keyboardType(.numberPad)
                    AutocompleteTextField(label: "Region", text: $region, suggestions: pastValues(\.region))
                }
                Section("Notes") {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(existingBottle == nil ? "Add Bottle" : "Edit Bottle")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onChange(of: photosPickerItem) { _, newItem in
                Task {
                    guard let data = try? await newItem?.loadTransferable(type: Data.self) else { return }
                    store(imageData: data)
                }
            }
            .fullScreenCover(isPresented: $isShowingCamera) {
                CameraCaptureView { image in
                    if let image {
                        store(imageData: image.jpegData(compressionQuality: 0.9))
                    }
                    isShowingCamera = false
                }
                .ignoresSafeArea()
            }
        }
    }

    /// Distinct, non-empty values previously entered for the given field, for autocomplete.
    private func pastValues(_ keyPath: KeyPath<Bottle, String>) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for bottle in bottles {
            let value = bottle[keyPath: keyPath].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty, seen.insert(value.lowercased()).inserted else { continue }
            result.append(value)
        }
        return result.sorted()
    }

    private func store(imageData: Data?) {
        guard let imageData, let uiImage = UIImage(data: imageData) else { return }
        photoData = uiImage.resized(maxDimension: 1000).jpegData(compressionQuality: 0.8)
    }

    private func save() {
        let vintage = Int(vintageText)
        if let bottle = existingBottle {
            bottle.name = name
            bottle.producer = producer
            bottle.wineType = wineType
            bottle.vintage = vintage
            bottle.region = region
            bottle.notes = notes
            bottle.photoData = photoData
        } else {
            let bottle = Bottle(
                name: name,
                producer: producer,
                wineType: wineType,
                vintage: vintage,
                region: region,
                notes: notes,
                slot: slotForNewBottle,
                photoData: photoData
            )
            modelContext.insert(bottle)
        }
        dismiss()
    }
}
