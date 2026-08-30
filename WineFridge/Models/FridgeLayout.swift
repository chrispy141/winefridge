//
//  FridgeLayout.swift
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
        CodableRepresentation(contentType: .wineFridgeSlot)
    }
}

nonisolated extension UTType {
    static var wineFridgeSlot: UTType {
        UTType(exportedAs: "com.winefridge.slotid")
    }
}

/// A quick way to set both `rowCount` and `slotsPerRow` on a shelf at once.
struct ShelfLayoutPreset: Identifiable {
    let name: String
    let rowCount: Int
    let slotsPerRow: Int

    var id: String { name }

    static let all: [ShelfLayoutPreset] = [
        ShelfLayoutPreset(name: "Single Row · 4", rowCount: 1, slotsPerRow: 4),
        ShelfLayoutPreset(name: "Single Row · 6", rowCount: 1, slotsPerRow: 6),
        ShelfLayoutPreset(name: "Double Row · 4 per row", rowCount: 2, slotsPerRow: 4),
        ShelfLayoutPreset(name: "Double Row · 6 per row", rowCount: 2, slotsPerRow: 6),
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
