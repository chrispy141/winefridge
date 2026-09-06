//
//  StorageLayout.swift
//  WineFridge
//

import Foundation
import CoreTransferable
import UniformTypeIdentifiers

nonisolated struct SlotID: Hashable, Identifiable, Codable {
    let shelfID: UUID
    let row: Int
    let column: Int

    var id: String { "\(shelfID)-\(row)-\(column)" }
}

nonisolated extension SlotID: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .wineStorageSlot)
    }
}

nonisolated extension UTType {
    static var wineStorageSlot: UTType {
        UTType(exportedAs: "com.winestorage.slotid")
    }
}

/// A quick way to set a shelf's `rowSlotCounts` all at once.
struct ShelfLayoutPreset: Identifiable {
    let name: String
    let rowSlotCounts: [Int]
    /// Whether rows should nest via the half-width offset. Pyramid layouts
    /// already taper via their differing row counts, so they leave this off
    /// to avoid double-offsetting.
    let isOffsetRows: Bool

    var id: String { name }

    static let all: [ShelfLayoutPreset] = [
        ShelfLayoutPreset(name: "Single Row · 4", rowSlotCounts: [4], isOffsetRows: true),
        ShelfLayoutPreset(name: "Single Row · 6", rowSlotCounts: [6], isOffsetRows: true),
        ShelfLayoutPreset(name: "Double Row · 4 per row", rowSlotCounts: [4, 4], isOffsetRows: true),
        ShelfLayoutPreset(name: "Double Row · 6 per row", rowSlotCounts: [6, 6], isOffsetRows: true),
        ShelfLayoutPreset(name: "Pyramid · 6-5-4", rowSlotCounts: [6, 5, 4], isOffsetRows: false),
    ]
}

extension SlotID {
    /// A human-readable description of this slot, e.g. "Shelf 2, Row 1, Position 3"
    /// (single-row shelves omit the row). Returns "Unplaced" if the shelf no longer exists.
    static func locationDescription(for slot: SlotID?, shelves: [Shelf]) -> String {
        guard let slot, let index = shelves.firstIndex(where: { $0.shelfID == slot.shelfID }) else {
            return "Unplaced"
        }
        let shelf = shelves[index]
        if shelf.rowCount > 1 {
            return "Shelf \(index + 1), Row \(slot.row + 1), Position \(slot.column + 1)"
        } else {
            return "Shelf \(index + 1), Position \(slot.column + 1)"
        }
    }
}
