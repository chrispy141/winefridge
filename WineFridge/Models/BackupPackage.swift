//
//  BackupPackage.swift
//  WineFridge
//

import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static var wineStorageBackup: UTType {
        UTType(exportedAs: "com.winestorage.backup")
    }
}

/// A complete, self-contained snapshot of every storage unit, shelf, and
/// bottle (including bottle photos) that can be written to a single file and
/// later used to replace whatever is currently in the store.
struct BackupPackage: Codable {
    struct StorageRecord: Codable {
        var storageID: UUID
        var name: String
        var position: Int
        var dateCreated: Date
        var icon: FridgeIcon?
    }

    struct ShelfRecord: Codable {
        var shelfID: UUID
        var storageID: UUID
        var position: Int
        var rowSlotCounts: [Int]
        /// Optional (rather than defaulted) so backups made before this field
        /// existed still decode; `restore` treats a missing value as `true`.
        var isOffsetRows: Bool?
    }

    struct BottleRecord: Codable {
        var name: String
        var producer: String
        var wineType: WineType
        var vintage: Int?
        var region: String
        var notes: String
        var dateAdded: Date
        var slot: SlotID?
        var photoData: Data?
    }

    var createdDate: Date
    var storages: [StorageRecord]
    var shelves: [ShelfRecord]
    var bottles: [BottleRecord]

    init(modelContext: ModelContext) throws {
        createdDate = .now
        storages = try modelContext.fetch(FetchDescriptor<Storage>()).map {
            StorageRecord(storageID: $0.storageID, name: $0.name, position: $0.position, dateCreated: $0.dateCreated, icon: $0.icon)
        }
        shelves = try modelContext.fetch(FetchDescriptor<Shelf>()).map {
            ShelfRecord(shelfID: $0.shelfID, storageID: $0.storageID, position: $0.position, rowSlotCounts: $0.rowSlotCounts, isOffsetRows: $0.isOffsetRows)
        }
        bottles = try modelContext.fetch(FetchDescriptor<Bottle>()).map {
            BottleRecord(
                name: $0.name,
                producer: $0.producer,
                wineType: $0.wineType,
                vintage: $0.vintage,
                region: $0.region,
                notes: $0.notes,
                dateAdded: $0.dateAdded,
                slot: $0.slot,
                photoData: $0.photoData
            )
        }
    }

    init(data: Data) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self = try decoder.decode(BackupPackage.self, from: data)
    }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }

    /// Deletes everything currently in the store and replaces it with the
    /// contents of this backup. Shelf and storage identities are preserved
    /// so bottle slot placements still resolve correctly after the restore.
    func restore(into modelContext: ModelContext) throws {
        for bottle in try modelContext.fetch(FetchDescriptor<Bottle>()) {
            modelContext.delete(bottle)
        }
        for shelf in try modelContext.fetch(FetchDescriptor<Shelf>()) {
            modelContext.delete(shelf)
        }
        for storage in try modelContext.fetch(FetchDescriptor<Storage>()) {
            modelContext.delete(storage)
        }

        for record in storages {
            let storage = Storage(name: record.name, position: record.position, dateCreated: record.dateCreated)
            storage.storageID = record.storageID
            storage.icon = record.icon
            modelContext.insert(storage)
        }
        for record in shelves {
            let shelf = Shelf(position: record.position, rowSlotCounts: record.rowSlotCounts, isOffsetRows: record.isOffsetRows ?? true, storageID: record.storageID)
            shelf.shelfID = record.shelfID
            modelContext.insert(shelf)
        }
        for record in bottles {
            let bottle = Bottle(
                name: record.name,
                producer: record.producer,
                wineType: record.wineType,
                vintage: record.vintage,
                region: record.region,
                notes: record.notes,
                dateAdded: record.dateAdded,
                slot: record.slot,
                photoData: record.photoData
            )
            modelContext.insert(bottle)
        }

        try modelContext.save()
    }
}

/// Wraps an encoded `BackupPackage` so it can be exported through SwiftUI's
/// `fileExporter`, letting the user pick where to save it and what to name it.
struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.wineStorageBackup] }
    static var writableContentTypes: [UTType] { [.wineStorageBackup] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
