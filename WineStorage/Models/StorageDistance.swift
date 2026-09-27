//
//  StorageDistance.swift
//  WineStorage
//

import Foundation

/// Computes a deterministic, logical distance between two storage slots,
/// using the actual shelf/row/column/storage-unit structure of the existing
/// storage model rather than assuming any particular fridge layout.
///
/// Distance is a weighted sum across the levels of that structure — column,
/// row, shelf, storage unit — so it naturally increases the further apart
/// two slots are hierarchically, without needing special-cased branches for
/// every combination:
///
/// - Positions beside each other in the same row differ only in column.
/// - Positions in an adjacent row on the same shelf add a row term.
/// - Positions on a different shelf (same storage unit) add a much larger
///   shelf term, since crossing shelves is a bigger physical gap than
///   crossing rows.
/// - Positions in a different storage unit add an even larger, flat
///   penalty, since two storage units are physically separate regardless of
///   their internal shelf/row/column coordinates.
///
/// The weights are chosen so that, for any storage unit of realistic size,
/// a farther-in-hierarchy pair (e.g. adjacent shelves) always scores farther
/// than any nearer-in-hierarchy pair (e.g. any same-shelf pair) — see the
/// doc comments on each weight. This isn't mathematically guaranteed for
/// pathologically large shelves, but it doesn't need to be: distances that
/// large already collapse to a near-zero `distanceWeight` (see
/// `WinePlacementService`), so any remaining tier overlap has negligible
/// effect on placement.
enum StorageDistance {
    /// Named weights for each level of the storage hierarchy, kept together
    /// so the "closeness" of each kind of neighbor is easy to see and retune
    /// in one place.
    enum Weights {
        /// Cost per column apart, within the same row.
        static let perColumn: Double = 1.0
        /// Cost per row apart, within the same shelf.
        static let perRow: Double = 1.5
        /// Flat cost added whenever two slots are on different shelves
        /// (before `perShelf` below), so even adjacent shelves are clearly
        /// farther than any same-shelf pair.
        static let shelfBase: Double = 10.0
        /// Additional cost per shelf-position apart, on top of `shelfBase`.
        static let perShelf: Double = 4.0
        /// Flat cost for slots in different storage units — deliberately
        /// large and non-scaling, since two storage units are "substantially
        /// farther apart" regardless of their internal coordinates.
        static let differentStorageUnit: Double = 100.0
    }

    /// The resolved logical coordinates of a slot, looked up from its shelf.
    /// A `SlotID` alone only carries a shelf identity, row, and column — this
    /// pulls in the shelf's storage unit and display position (needed to
    /// tell shelves apart and order them) so distance can be computed.
    struct Coordinates {
        let storageID: UUID
        let shelfID: UUID
        let shelfPosition: Int
        let row: Int
        let column: Int
    }

    static func coordinates(of slot: SlotID, shelvesByID: [UUID: Shelf]) -> Coordinates? {
        guard let shelf = shelvesByID[slot.shelfID] else { return nil }
        return Coordinates(
            storageID: shelf.storageID,
            shelfID: shelf.shelfID,
            shelfPosition: shelf.position,
            row: slot.row,
            column: slot.column
        )
    }

    /// The logical distance between two slots. Larger means farther apart;
    /// `0` only for the same slot.
    static func distance(_ a: Coordinates, _ b: Coordinates) -> Double {
        guard a.storageID == b.storageID else {
            return Weights.differentStorageUnit
        }
        guard a.shelfID == b.shelfID else {
            let shelfDelta = Double(abs(a.shelfPosition - b.shelfPosition))
            return Weights.shelfBase + (shelfDelta - 1) * Weights.perShelf
        }
        let rowDelta = Double(abs(a.row - b.row))
        let columnDelta = Double(abs(a.column - b.column))
        return rowDelta * Weights.perRow + columnDelta * Weights.perColumn
    }

    /// A decreasing weight derived from `distance` — see
    /// `WinePlacementService` for how it's combined with wine similarity.
    /// Nearby bottles matter a lot; far-away ones fade out but are never
    /// entirely ignored, letting a cluster several positions away still
    /// exert some pull.
    static func distanceWeight(forDistance distance: Double) -> Double {
        1.0 / (1.0 + distance)
    }

    /// Whether two slots are immediate physical neighbors: side-by-side in
    /// the same row, or roughly aligned in an adjacent row on the same
    /// shelf. Used for the immediate-neighbor bonus and the fragmentation
    /// tie-breaker, both of which care about tight, compact adjacency rather
    /// than the general decaying distance above.
    static func areImmediateNeighbors(_ a: Coordinates, _ b: Coordinates) -> Bool {
        guard a.shelfID == b.shelfID else { return false }
        let rowDelta = abs(a.row - b.row)
        let columnDelta = abs(a.column - b.column)
        switch rowDelta {
        case 0: return columnDelta == 1
        case 1: return columnDelta <= 1
        default: return false
        }
    }

    /// Every valid slot coordinate on `shelf` that's an immediate neighbor of
    /// `slot`, respecting each row's own slot count (rows may differ in
    /// length, e.g. a pyramid-style rack).
    static func immediateNeighborSlots(of slot: SlotID, on shelf: Shelf) -> [SlotID] {
        let rowSlotCounts = shelf.rowSlotCounts
        guard shelf.shelfID == slot.shelfID, rowSlotCounts.indices.contains(slot.row) else { return [] }
        var neighbors: [SlotID] = []

        if slot.column - 1 >= 0 {
            neighbors.append(SlotID(shelfID: slot.shelfID, row: slot.row, column: slot.column - 1))
        }
        if slot.column + 1 < rowSlotCounts[slot.row] {
            neighbors.append(SlotID(shelfID: slot.shelfID, row: slot.row, column: slot.column + 1))
        }
        for adjacentRow in [slot.row - 1, slot.row + 1] where rowSlotCounts.indices.contains(adjacentRow) {
            let count = rowSlotCounts[adjacentRow]
            for column in [slot.column - 1, slot.column, slot.column + 1] where column >= 0 && column < count {
                neighbors.append(SlotID(shelfID: slot.shelfID, row: adjacentRow, column: column))
            }
        }
        return neighbors
    }
}
