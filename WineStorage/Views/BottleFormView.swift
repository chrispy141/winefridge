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
    @State private var varietal: String
    @State private var vintageText: String
    @State private var country: String
    @State private var region: String
    @State private var appellation: String
    @State private var vineyard: String
    @State private var designation: String
    @State private var bottleSize: BottleSize
    @State private var abvText: String
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
        _varietal = State(initialValue: "")
        _vintageText = State(initialValue: "")
        _country = State(initialValue: "")
        _region = State(initialValue: "")
        _appellation = State(initialValue: "")
        _vineyard = State(initialValue: "")
        _designation = State(initialValue: "")
        _bottleSize = State(initialValue: .standard)
        _abvText = State(initialValue: "")
        _notes = State(initialValue: "")
        _photoData = State(initialValue: nil)
    }

    init(editing bottle: Bottle) {
        existingBottle = bottle
        slotForNewBottle = nil
        _name = State(initialValue: bottle.name)
        _producer = State(initialValue: bottle.producer)
        _wineType = State(initialValue: bottle.wineType)
        _varietal = State(initialValue: bottle.varietal)
        _vintageText = State(initialValue: bottle.vintage.map(String.init) ?? "")
        _country = State(initialValue: bottle.country)
        _region = State(initialValue: bottle.region)
        _appellation = State(initialValue: bottle.appellation)
        _vineyard = State(initialValue: bottle.vineyard)
        _designation = State(initialValue: bottle.designation)
        _bottleSize = State(initialValue: bottle.bottleSize)
        _abvText = State(initialValue: bottle.abv.map { String($0) } ?? "")
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
                    AutocompleteTextField(label: "Producer (e.g. Stag’s Leap Wine Cellars)", text: $producer, suggestions: pastValues(\.producer))
                    AutocompleteTextField(label: "Wine / Cuvée (e.g. CASK 23)", text: $name, suggestions: pastValues(\.name))
                    AutocompleteTextField(label: "Varietal / Blend (e.g. Cabernet Sauvignon)", text: $varietal, suggestions: pastValues(\.varietal))
                    Picker("Style", selection: $wineType) {
                        ForEach(WineType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    TextField("Vintage (e.g. 2022)", text: $vintageText)
                        .keyboardType(.numberPad)
                }
                Section("Origin") {
                    AutocompleteTextField(label: "Country (e.g. United States)", text: $country, suggestions: pastValues(\.country))
                    AutocompleteTextField(label: "Region (e.g. Napa Valley)", text: $region, suggestions: pastValues(\.region))
                    AutocompleteTextField(label: "Appellation (e.g. Stags Leap District)", text: $appellation, suggestions: pastValues(\.appellation))
                    AutocompleteTextField(label: "Vineyard (e.g. S.L.V. & FAY Vineyards)", text: $vineyard, suggestions: pastValues(\.vineyard))
                    AutocompleteTextField(label: "Designation / Tier (e.g. Estate)", text: $designation, suggestions: pastValues(\.designation))
                }
                Section("Bottle") {
                    Picker("Bottle Size", selection: $bottleSize) {
                        ForEach(BottleSize.allCases) { size in
                            Text(size.rawValue).tag(size)
                        }
                    }
                    HStack {
                        TextField("ABV (e.g. 14.8)", text: $abvText)
                            .keyboardType(.decimalPad)
                        Text("%")
                            .foregroundStyle(.secondary)
                    }
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
        let abv = Double(abvText)
        if let bottle = existingBottle {
            bottle.name = name
            bottle.producer = producer
            bottle.wineType = wineType
            bottle.varietal = varietal
            bottle.vintage = vintage
            bottle.country = country
            bottle.region = region
            bottle.appellation = appellation
            bottle.vineyard = vineyard
            bottle.designation = designation
            bottle.bottleSize = bottleSize
            bottle.abv = abv
            bottle.notes = notes
            bottle.photoData = photoData
        } else {
            let bottle = Bottle(
                name: name,
                producer: producer,
                wineType: wineType,
                varietal: varietal,
                vintage: vintage,
                country: country,
                region: region,
                appellation: appellation,
                vineyard: vineyard,
                designation: designation,
                bottleSize: bottleSize,
                abv: abv,
                notes: notes,
                slot: slotForNewBottle,
                photoData: photoData
            )
            modelContext.insert(bottle)
        }
        dismiss()
    }
}
