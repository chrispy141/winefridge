//
//  BottleFormView.swift
//  WineStorage
//

import SwiftUI
import SwiftData
import PhotosUI
import UIKit

/// Add or edit a bottle. Use `init(newBottleSlot:initialPhotoData:prefilledExtraction:onSave:)`
/// to create a bottle — pass a slot to place it directly on a shelf, or
/// `nil` to leave it unplaced in the shared, storage-agnostic inventory
/// (e.g. Quick Add places the bottle itself once a location is chosen) —
/// or `init(editing:)` to edit an existing bottle in place.
struct BottleFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var bottles: [Bottle]

    private let existingBottle: Bottle?
    private let slotForNewBottle: SlotID?
    /// Called with the saved bottle right before the form dismisses itself,
    /// so a caller like Quick Add — which needs the bottle to continue its
    /// own flow (choosing where to place it) — doesn't have to re-derive it.
    private let onSave: ((Bottle) -> Void)?

    @State private var name: String
    @State private var producer: String
    @State private var wineType: WineType
    @State private var varietal: String
    @State private var vintageSelection: Bottle.VintageSelection
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
    @State private var isShowingPhotoPicker = false

    @State private var isScanningLabel = false
    @State private var labelScanAlert: LabelScanAlert?

    /// - Parameters:
    ///   - slot: Where to place the bottle once saved, or `nil` to leave it
    ///     unplaced in the shared inventory (e.g. for Quick Add, which places
    ///     the bottle itself once a location has been chosen).
    ///   - initialPhotoData: A label photo to start the form with, such as
    ///     the photo Quick Add just scanned.
    ///   - extraction: Recognized label fields (see `WineLabelScanner`) to
    ///     pre-populate the form with. Every field is still editable before
    ///     saving — nothing here is committed until the person taps Save.
    ///   - onSave: Called with the saved bottle right before the form
    ///     dismisses, so a caller can continue its own flow with it.
    init(
        newBottleSlot slot: SlotID? = nil,
        initialPhotoData: Data? = nil,
        prefilledExtraction extraction: WineLabelExtraction? = nil,
        onSave: ((Bottle) -> Void)? = nil
    ) {
        existingBottle = nil
        slotForNewBottle = slot
        self.onSave = onSave
        _name = State(initialValue: extraction?.wineName ?? "")
        _producer = State(initialValue: extraction?.producer ?? "")
        _wineType = State(initialValue: extraction?.wineType ?? .unknown)
        _varietal = State(initialValue: extraction?.varietal ?? "")
        // Positioned at the current year so someone adding a bottle doesn't
        // need to scroll the wheel from 1800; Unknown and NV are still just
        // a couple of rows away. A prefilled extraction's vintage overrides
        // this the same way typing one in would.
        if extraction?.isNonVintage == true {
            _vintageSelection = State(initialValue: .nonVintage)
        } else if let vintage = extraction?.vintage {
            _vintageSelection = State(initialValue: .year(vintage))
        } else {
            _vintageSelection = State(initialValue: .year(Self.currentYear))
        }
        _country = State(initialValue: extraction?.country ?? "")
        _region = State(initialValue: extraction?.region ?? "")
        _appellation = State(initialValue: extraction?.appellation ?? "")
        _vineyard = State(initialValue: extraction?.vineyard ?? "")
        _designation = State(initialValue: extraction?.designation ?? "")
        _bottleSize = State(initialValue: extraction?.bottleSize ?? .standard)
        _abvText = State(initialValue: extraction?.abv.map { String($0) } ?? "")
        _notes = State(initialValue: "")
        _photoData = State(initialValue: initialPhotoData)
    }

    init(editing bottle: Bottle) {
        existingBottle = bottle
        slotForNewBottle = nil
        onSave = nil
        _name = State(initialValue: bottle.name)
        _producer = State(initialValue: bottle.producer)
        _wineType = State(initialValue: bottle.wineType)
        _varietal = State(initialValue: bottle.varietal)
        _vintageSelection = State(initialValue: bottle.vintageSelection)
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
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Menu {
                            Button {
                                isShowingCamera = true
                            } label: {
                                Label("Take Photo", systemImage: "camera")
                            }
                            Button {
                                isShowingPhotoPicker = true
                            } label: {
                                Label("Choose Photo", systemImage: "photo.on.rectangle")
                            }
                        } label: {
                            Label(photoData == nil ? "Add Photo" : "Change Photo", systemImage: "photo.badge.plus")
                        }
                    } else {
                        Button {
                            isShowingPhotoPicker = true
                        } label: {
                            Label(photoData == nil ? "Add Photo" : "Change Photo", systemImage: "photo.badge.plus")
                        }
                    }
                }
                Section {
                    HStack(spacing: 12) {
                        scanButton(title: "Update Blanks", systemImage: "text.badge.plus", fillBlanksOnly: true)
                        scanButton(title: "Update All", systemImage: "arrow.triangle.2.circlepath", fillBlanksOnly: false)
                    }
                    .disabled(isScanningLabel || photoData == nil)
                    if isScanningLabel {
                        HStack {
                            ProgressView()
                            Text("Scanning Label…")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Scan Wine Label")
                } footer: {
                    Text("Reads details from the photo above. “Update Blanks” only fills in empty fields; “Update All” replaces every recognized field.")
                }
                Section("Wine") {
                    AutocompleteTextField(title: "Producer", placeholder: "e.g. Stag’s Leap Wine Cellars", text: $producer, suggestions: pastValues(\.producer))
                    AutocompleteTextField(title: "Wine / Cuvée", placeholder: "e.g. CASK 23", text: $name, suggestions: pastValues(\.name))
                    AutocompleteTextField(title: "Varietal / Blend", placeholder: "e.g. Cabernet Sauvignon", text: $varietal, suggestions: pastValues(\.varietal))
                    Picker("Style", selection: $wineType) {
                        ForEach(WineType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Vintage")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Picker("Vintage", selection: $vintageSelection) {
                            ForEach(vintageOptions, id: \.self) { option in
                                Text(vintageLabel(for: option)).tag(option)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.wheel)
                    }
                }
                Section("Origin") {
                    AutocompleteTextField(title: "Country", placeholder: "e.g. United States", text: $country, suggestions: pastValues(\.country))
                    AutocompleteTextField(title: "Region", placeholder: "e.g. Napa Valley", text: $region, suggestions: pastValues(\.region))
                    AutocompleteTextField(title: "Appellation", placeholder: "e.g. Stags Leap District", text: $appellation, suggestions: pastValues(\.appellation))
                    AutocompleteTextField(title: "Vineyard", placeholder: "e.g. S.L.V. & FAY Vineyards", text: $vineyard, suggestions: pastValues(\.vineyard))
                    AutocompleteTextField(title: "Designation / Tier", placeholder: "e.g. Estate", text: $designation, suggestions: pastValues(\.designation))
                }
                Section("Bottle") {
                    Picker("Bottle Size", selection: $bottleSize) {
                        ForEach(BottleSize.allCases) { size in
                            Text(size.rawValue).tag(size)
                        }
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("ABV")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack {
                            TextField("e.g. 14.8", text: $abvText)
                                .keyboardType(.decimalPad)
                            Text("%")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Section("Notes") {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Notes")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Notes", text: $notes, axis: .vertical)
                            .lineLimit(3...6)
                    }
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
            .photosPicker(isPresented: $isShowingPhotoPicker, selection: $photosPickerItem, matching: .images)
            .fullScreenCover(isPresented: $isShowingCamera) {
                CameraCaptureView { image in
                    if let image {
                        store(imageData: image.jpegData(compressionQuality: 0.9))
                    }
                    isShowingCamera = false
                }
                .ignoresSafeArea()
            }
            .alert(item: $labelScanAlert) { alert in
                Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text("OK")))
            }
        }
    }

    private static let earliestVintageYear = 1800
    private static var currentYear: Int {
        Calendar.current.component(.year, from: .now)
    }

    /// All selectable vintage options, in wheel order: Unknown and NV first
    /// — so they're reachable without scrolling through every year — then
    /// years in descending order from this year back to `earliestVintageYear`.
    /// If the bottle already has a legacy vintage outside that range, it's
    /// included too, so editing it never silently discards the value.
    private var vintageOptions: [Bottle.VintageSelection] {
        var years = stride(from: Self.currentYear, through: Self.earliestVintageYear, by: -1)
            .map(Bottle.VintageSelection.year)
        if case .year(let legacyYear) = vintageSelection,
           !(Self.earliestVintageYear...Self.currentYear).contains(legacyYear) {
            if legacyYear > Self.currentYear {
                years.insert(.year(legacyYear), at: 0)
            } else {
                years.append(.year(legacyYear))
            }
        }
        return [.unknown, .nonVintage] + years
    }

    private func vintageLabel(for selection: Bottle.VintageSelection) -> String {
        switch selection {
        case .unknown: return "Unknown"
        case .nonVintage: return "NV"
        case .year(let year): return String(year)
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

    /// One of the two "Scan Wine Label" buttons — identical in every way
    /// except which scan mode they start (see `apply(_:fillBlanksOnly:)`).
    private func scanButton(title: String, systemImage: String, fillBlanksOnly: Bool) -> some View {
        Button {
            startLabelScan(fillBlanksOnly: fillBlanksOnly)
        } label: {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
    }

    /// Starts a "Scan Wine Label" flow by running OCR on the bottle's
    /// currently assigned photo. Both scan buttons are disabled when there's
    /// no photo, so scanning never needs to ask for one.
    ///
    /// - Parameter fillBlanksOnly: See `apply(_:fillBlanksOnly:)`.
    private func startLabelScan(fillBlanksOnly: Bool) {
        guard let photoData, let image = UIImage(data: photoData) else { return }
        runLabelScan(on: image, fillBlanksOnly: fillBlanksOnly)
    }

    /// Runs the on-device OCR + interpretation pipeline on a label photo and
    /// applies the result to the form (see `apply(_:fillBlanksOnly:)` for the
    /// overwrite policy).
    private func runLabelScan(on image: UIImage, fillBlanksOnly: Bool) {
        isScanningLabel = true
        Task {
            defer { isScanningLabel = false }
            do {
                switch try await WineLabelScanner.scan(image: image) {
                case .extracted(let extraction):
                    apply(extraction, fillBlanksOnly: fillBlanksOnly)
                case .interpreterUnavailable(let reason):
                    labelScanAlert = LabelScanAlert(
                        title: "Label Scanning Limited",
                        message: reason
                    )
                }
            } catch {
                labelScanAlert = LabelScanAlert(
                    title: "Couldn't Read Label",
                    message: "Try a clearer, well-lit photo of the label with the text facing the camera."
                )
            }
        }
    }

    /// Applies a label scan's results to the form.
    ///
    /// - Parameter fillBlanksOnly: When `true` ("Update Blanks"), only fills
    ///   in fields still blank — it never overwrites something already
    ///   typed. When `false` ("Update All"), recognized fields overwrite
    ///   whatever's currently there. Either way, nothing is saved until the
    ///   person reviews the form and taps Save.
    private func apply(_ extraction: WineLabelExtraction, fillBlanksOnly: Bool) {
        func apply(_ newValue: String?, to current: inout String) {
            guard let newValue else { return }
            if !fillBlanksOnly || current.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                current = newValue
            }
        }

        apply(extraction.wineName, to: &name)
        apply(extraction.producer, to: &producer)
        apply(extraction.varietal, to: &varietal)
        apply(extraction.designation, to: &designation)
        apply(extraction.country, to: &country)
        apply(extraction.region, to: &region)
        apply(extraction.appellation, to: &appellation)
        apply(extraction.vineyard, to: &vineyard)

        // A new bottle's vintage starts on the current year purely so the
        // wheel doesn't open scrolled away from today — that's not a
        // deliberate choice the way typing a value into a text field is, so
        // a scan is still free to override it exactly once, same as it
        // would fill in any other still-blank field.
        let untouchedNewBottleVintage = Bottle.VintageSelection.year(Self.currentYear)
        if let isNonVintage = extraction.isNonVintage, isNonVintage {
            if !fillBlanksOnly || vintageSelection == untouchedNewBottleVintage {
                vintageSelection = .nonVintage
            }
        } else if let vintage = extraction.vintage {
            if !fillBlanksOnly || vintageSelection == untouchedNewBottleVintage {
                vintageSelection = .year(vintage)
            }
        }
        if let abv = extraction.abv, !fillBlanksOnly || abvText.isEmpty {
            abvText = String(abv)
        }
        // `wineType`'s "Unknown" case is its blank state, same as an empty
        // string for the text fields above. `bottleSize` has no such case,
        // so "Update Blanks" leaves it untouched entirely — there's nothing
        // for it to consider blank — while "Update All" always overwrites it.
        if let wineType = extraction.wineType, !fillBlanksOnly || self.wineType == .unknown {
            self.wineType = wineType
        }
        if let bottleSize = extraction.bottleSize, !fillBlanksOnly {
            self.bottleSize = bottleSize
        }
    }

    private func save() {
        let abv = Double(abvText)
        let savedBottle: Bottle
        if let bottle = existingBottle {
            bottle.name = name
            bottle.producer = producer
            bottle.wineType = wineType
            bottle.varietal = varietal
            bottle.vintageSelection = vintageSelection
            bottle.country = country
            bottle.region = region
            bottle.appellation = appellation
            bottle.vineyard = vineyard
            bottle.designation = designation
            bottle.bottleSize = bottleSize
            bottle.abv = abv
            bottle.notes = notes
            bottle.photoData = photoData
            savedBottle = bottle
        } else {
            let bottle = Bottle(
                name: name,
                producer: producer,
                wineType: wineType,
                varietal: varietal,
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
            bottle.vintageSelection = vintageSelection
            modelContext.insert(bottle)
            savedBottle = bottle
        }
        onSave?(savedBottle)
        dismiss()
    }
}

/// A simple message shown when label scanning can't fully complete.
private struct LabelScanAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}
