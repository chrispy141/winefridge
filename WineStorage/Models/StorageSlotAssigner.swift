//
//  StorageSlotAssigner.swift
//  WineStorage
//

import Foundation

/// Finds empty shelf slots within a storage unit's natural display order —
/// shared by anything that needs to place a bottle without a person manually
/// picking a slot (currently just Quick Add's "Auto Assign").
///
/// Kept as a plain model-layer type, independent of SwiftUI, so the
/// selection policy can be swapped out (e.g. for something smarter than
/// "first empty slot") without touching the views that use it.
enum StorageSlotAssigner {
    /// The slots currently occupied by any of the given bottles.
    static func occupiedSlots(in bottles: [Bottle]) -> Set<SlotID> {
        Set(bottles.compactMap(\.slot))
    }

    /// Every empty slot on the given shelves, in the same order they're
    /// displayed in — shelf position, then row, then column.
    static func availableSlots(onShelves shelves: [Shelf], occupying bottles: [Bottle]) -> [SlotID] {
        let occupied = occupiedSlots(in: bottles)
        return shelves
            .sorted { $0.position < $1.position }
            .flatMap { shelf in
                shelf.rowSlotCounts.enumerated().flatMap { rowIndex, count in
                    (0..<count).map { column in SlotID(shelfID: shelf.shelfID, row: rowIndex, column: column) }
                }
            }
            .filter { !occupied.contains($0) }
    }

    /// The slot Auto Assign should use: the first empty slot in natural
    /// display order, or `nil` if the storage unit is full. Isolated as its
    /// own method so a more sophisticated placement strategy could replace
    /// just this policy later without redesigning callers.
    static func firstAvailableSlot(onShelves shelves: [Shelf], occupying bottles: [Bottle]) -> SlotID? {
        availableSlots(onShelves: shelves, occupying: bottles).first
    }

    /// Whether `slot` is still empty. Callers should re-check this
    /// immediately before committing a placement — chosen earlier, a slot
    /// may have since been filled by a sync from another device.
    static func isAvailable(_ slot: SlotID, occupying bottles: [Bottle]) -> Bool {
        !occupiedSlots(in: bottles).contains(slot)
    }
}
