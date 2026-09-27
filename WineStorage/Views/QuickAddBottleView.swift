//
//  QuickAddBottleView.swift
//  WineStorage
//

import SwiftUI
import SwiftData
import PhotosUI
import UIKit

/// Orchestrates the "Quick Add" workflow started from the Wine Storage
/// screen: snap or pick a wine-label photo, run the existing on-device OCR +
/// Foundation Models pipeline (`WineLabelScanner`), review/correct the
/// recognized bottle in the existing `BottleFormView`, then place it on a
/// shelf — either by auto-assigning the first available slot
/// (`StorageSlotAssigner`) or by picking one from the existing storage
/// visualization (`StorageView` in its "Choose Location" mode).
///
/// The bottle is only ever created once the person confirms the form —
/// exactly like the ordinary Add Bottle flow — as an unplaced inventory
/// bottle. It's only *placed* on a shelf once a slot is chosen and
/// re-verified as still empty. If the flow is cancelled after the bottle
/// exists but before a location is committed, that bottle is deleted so
/// nothing is left orphaned behind.
struct QuickAddBottleView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let storage: Storage
    @Query(sort: \Storage.position) private var allStorages: [Storage]

    @State private var phase: Phase = .pickSource
    @State private var locationStorage: Storage

    @State private var isShowingCamera = false
    @State private var isShowingPhotoPicker = false
    @State private var photosPickerItem: PhotosPickerItem?

    @State private var reviewContext: ReviewContext?
    @State private var didProduceBottleFromReview = false

    @State private var errorAlert: QuickAddAlert?

    init(storage: Storage) {
        self.storage = storage
        _locationStorage = State(initialValue: storage)
    }

    private enum Phase {
        case pickSource
        case scanning
        case chooseAssignment(Bottle)
        case chooseLocation(Bottle)
        case placed(Bottle, String)
        case storageFull(Bottle)
        case pickAlternateStorage(Bottle)
    }

    private struct ReviewContext: Identifiable {
        let id = UUID()
        let photoData: Data?
        let extraction: WineLabelExtraction?
    }

    private var otherStorages: [Storage] {
        allStorages.filter { $0.storageID != storage.storageID }
    }

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .pickSource:
                    pickSourceView
                case .scanning:
                    scanningView
                case .chooseAssignment(let bottle):
                    chooseAssignmentView(bottle: bottle)
                case .chooseLocation(let bottle):
                    StorageView(storage: locationStorage) { slot in
                        commitPlacement(bottle: bottle, slot: slot, inStorage: locationStorage)
                    }
                case .placed(let bottle, let locationDescription):
                    placedView(bottle: bottle, locationDescription: locationDescription)
                case .storageFull(let bottle):
                    storageFullView(bottle: bottle)
                case .pickAlternateStorage(let bottle):
                    pickAlternateStorageView(bottle: bottle)
                }
            }
            .navigationTitle("Quick Add")
            .toolbar { toolbarContent }
        }
        .interactiveDismissDisabled()
        .onChange(of: photosPickerItem) { _, newItem in
            Task {
                guard let data = try? await newItem?.loadTransferable(type: Data.self),
                      let image = UIImage(data: data) else { return }
                beginScan(on: image)
            }
        }
        .photosPicker(isPresented: $isShowingPhotoPicker, selection: $photosPickerItem, matching: .images)
        .fullScreenCover(isPresented: $isShowingCamera) {
            CameraCaptureView { image in
                isShowingCamera = false
                if let image {
                    beginScan(on: image)
                }
            }
            .ignoresSafeArea()
        }
        .fullScreenCover(item: $reviewContext, onDismiss: reviewDismissed) { context in
            BottleFormView(
                initialPhotoData: context.photoData,
                prefilledExtraction: context.extraction,
                onSave: { bottle in
                    didProduceBottleFromReview = true
                    phase = .chooseAssignment(bottle)
                }
            )
        }
        .alert(item: $errorAlert) { alert in
            Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text("OK")))
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        switch phase {
        case .pickSource, .scanning:
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
        case .chooseAssignment(let bottle), .storageFull(let bottle), .pickAlternateStorage(let bottle):
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", role: .destructive) {
                    modelContext.delete(bottle)
                    dismiss()
                }
            }
        case .chooseLocation(let bottle):
            ToolbarItem(placement: .cancellationAction) {
                Button("Back") { phase = .chooseAssignment(bottle) }
            }
        case .placed:
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") { dismiss() }
            }
        }
    }

    // MARK: - Step views

    /// Matches the photo-source control in `BottleFormView`'s "Photo"
    /// section: a native pull-down menu when the camera is available, or a
    /// direct photo-picker button otherwise.
    private var pickSourceView: some View {
        ContentUnavailableView {
            Label("Add a Wine Label Photo", systemImage: "camera.viewfinder")
        } description: {
            Text("Take or choose a photo of the label to get started.")
        } actions: {
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
                    Label("Add Wine Label Photo", systemImage: "photo.badge.plus")
                }
            } else {
                Button {
                    isShowingPhotoPicker = true
                } label: {
                    Label("Add Wine Label Photo", systemImage: "photo.badge.plus")
                }
            }
        }
    }

    private var scanningView: some View {
        VStack(spacing: 16) {
            ProgressView()
            Text("Reading wine label…")
                .foregroundStyle(.secondary)
        }
    }

    private func chooseAssignmentView(bottle: Bottle) -> some View {
        VStack(spacing: 24) {
            Spacer()
            VStack(spacing: 6) {
                Text(bottleSummary(bottle))
                    .font(.headline)
                    .multilineTextAlignment(.center)
                Text("Ready to place this bottle in \(storage.name).")
                    .foregroundStyle(.secondary)
            }
            VStack(spacing: 12) {
                Button {
                    autoAssign(bottle: bottle)
                } label: {
                    Label("Auto Assign", systemImage: "wand.and.stars")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button {
                    locationStorage = storage
                    phase = .chooseLocation(bottle)
                } label: {
                    Label("Choose Location", systemImage: "square.grid.3x3")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            Spacer()
        }
        .padding()
    }

    private func placedView(bottle: Bottle, locationDescription: String) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)
            Text("Bottle Added")
                .font(.title2.bold())
            VStack(spacing: 6) {
                Text("Place this bottle in:")
                    .foregroundStyle(.secondary)
                Text(locationDescription)
                    .font(.title3.bold())
                    .multilineTextAlignment(.center)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
            Text(bottleSummary(bottle))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding()
    }

    private func storageFullView(bottle: Bottle) -> some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "square.grid.3x3.fill.square")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("\(storage.name) Is Full")
                .font(.title2.bold())
            Text("There are no empty slots left. The bottle has been saved to your inventory — place it once space opens up, or choose another storage area now.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            VStack(spacing: 12) {
                Button {
                    autoAssign(bottle: bottle)
                } label: {
                    Label("Try Auto Assign Again", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                if !otherStorages.isEmpty {
                    Button {
                        phase = .pickAlternateStorage(bottle)
                    } label: {
                        Label("Choose a Different Storage", systemImage: "square.grid.3x2")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            Spacer()
        }
        .padding()
    }

    private func pickAlternateStorageView(bottle: Bottle) -> some View {
        List(otherStorages) { alternate in
            Button {
                locationStorage = alternate
                phase = .chooseLocation(bottle)
            } label: {
                Text(alternate.name)
            }
        }
        .navigationTitle("Choose Storage")
    }

    // MARK: - Actions

    /// Runs the existing OCR + Foundation Models pipeline on `image`, then
    /// hands off to the existing Add/Edit Bottle form for review — pre-filled
    /// with whatever was recognized, even if that's incomplete or nothing at
    /// all, so a poor scan never blocks the person from continuing by hand.
    private func beginScan(on image: UIImage) {
        phase = .scanning
        Task {
            var extraction: WineLabelExtraction?
            do {
                switch try await WineLabelScanner.scan(image: image) {
                case .extracted(let result):
                    extraction = result
                case .interpreterUnavailable(let reason):
                    errorAlert = QuickAddAlert(title: "Label Scanning Limited", message: reason)
                }
            } catch {
                errorAlert = QuickAddAlert(
                    title: "Couldn't Read Label",
                    message: "Try a clearer, well-lit photo with the text facing the camera. You can still fill in the details by hand."
                )
            }
            let photoData = image.resized(maxDimension: 1000).jpegData(compressionQuality: 0.8)
            reviewContext = ReviewContext(photoData: photoData, extraction: extraction)
        }
    }

    /// If the review form was dismissed without saving (Cancel), there's no
    /// bottle yet, so return to the beginning rather than continuing the flow.
    private func reviewDismissed() {
        if !didProduceBottleFromReview {
            phase = .pickSource
        }
        didProduceBottleFromReview = false
    }

    /// Auto Assign: place the bottle in whichever empty slot in `storage`
    /// scores best for grouping it near similar existing wines (see
    /// `WinePlacementService`), falling back to the first available slot in
    /// natural order when there's no meaningful similarity signal.
    private func autoAssign(bottle: Bottle) {
        let shelves = fetchShelves(for: storage)
        let bottles = fetchAllBottles()
        guard let recommendation = WinePlacementService.findBestSlot(
            for: bottle,
            in: storage,
            allShelves: fetchAllShelves(),
            allBottles: bottles
        ) else {
            phase = .storageFull(bottle)
            return
        }
        commitPlacement(bottle: bottle, slot: recommendation.slot, inStorage: storage, shelves: shelves)
    }

    private func commitPlacement(bottle: Bottle, slot: SlotID, inStorage storage: Storage) {
        commitPlacement(bottle: bottle, slot: slot, inStorage: storage, shelves: fetchShelves(for: storage))
    }

    /// Commits a bottle's placement after re-verifying, against a fresh
    /// fetch, that the slot is still empty — inventory may have changed
    /// since it was chosen, e.g. via iCloud sync from another device.
    private func commitPlacement(bottle: Bottle, slot: SlotID, inStorage storage: Storage, shelves: [Shelf]) {
        let freshBottles = fetchAllBottles()
        guard StorageSlotAssigner.isAvailable(slot, occupying: freshBottles) else {
            errorAlert = QuickAddAlert(
                title: "Slot No Longer Available",
                message: "That spot was just taken by another bottle. Choose a different location, or try Auto Assign again."
            )
            phase = .chooseAssignment(bottle)
            return
        }
        bottle.slot = slot
        let slotDescription = SlotID.locationDescription(for: slot, shelves: shelves)
        phase = .placed(bottle, multilineLocation(storageName: storage.name, slotDescription: slotDescription))
    }

    private func fetchAllBottles() -> [Bottle] {
        (try? modelContext.fetch(FetchDescriptor<Bottle>())) ?? []
    }

    private func fetchShelves(for storage: Storage) -> [Shelf] {
        let storageID = storage.storageID
        let descriptor = FetchDescriptor<Shelf>(
            predicate: #Predicate { $0.storageID == storageID },
            sortBy: [SortDescriptor(\.position)]
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// Every shelf across every storage unit — `WinePlacementService` needs
    /// this to resolve the location of bottles placed outside `storage`,
    /// even though only `storage`'s own shelves are candidates for placement.
    private func fetchAllShelves() -> [Shelf] {
        (try? modelContext.fetch(FetchDescriptor<Shelf>())) ?? []
    }

    /// Formats a slot's location, storage name first, as separate lines so
    /// it reads clearly at a glance while walking up to the physical
    /// storage — reusing the same terminology `SlotID.locationDescription`
    /// already produces, just laid out for prominence.
    private func multilineLocation(storageName: String, slotDescription: String) -> String {
        ([storageName] + slotDescription.split(separator: ", ").map(String.init)).joined(separator: "\n")
    }

    private func bottleSummary(_ bottle: Bottle) -> String {
        var parts: [String] = []
        if !bottle.producer.isEmpty { parts.append(bottle.producer) }
        parts.append(bottle.name.isEmpty ? "Untitled Bottle" : bottle.name)
        if let vintageDisplayText = bottle.vintageDisplayText { parts.append(vintageDisplayText) }
        return parts.joined(separator: " · ")
    }
}

/// A simple message shown for Quick Add's non-blocking scan/placement issues.
private struct QuickAddAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

#Preview {
    QuickAddBottleView(storage: Storage(name: "Wine Storage", position: 0))
        .modelContainer(for: [Storage.self, Bottle.self, Shelf.self], inMemory: true)
}
