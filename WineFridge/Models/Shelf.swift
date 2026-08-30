//
//  Shelf.swift
//  WineFridge
//

import Foundation
import SwiftData

@Model
final class Shelf {
    /// Display/sort order among all shelves. Kept in sync on add/remove/reorder.
    var position: Int
    /// Stable identity used by `SlotID`, independent of `position` so reordering
    /// shelves never disturbs existing bottle placements.
    var shelfID: UUID
    /// 1 or 2.
    var rowCount: Int
    var slotsPerRow: Int

    init(position: Int, rowCount: Int = 2, slotsPerRow: Int = 4) {
        self.position = position
        self.shelfID = UUID()
        self.rowCount = rowCount
        self.slotsPerRow = slotsPerRow
    }

    /// Inserts the fridge's original fixed layout: six double-row shelves of 4,
    /// plus a single-row shelf of 6 (the old "bottom row"). Only meant to run
    /// once, when the store has no shelves yet.
    static func seedDefaults(in context: ModelContext) {
        for position in 0..<6 {
            context.insert(Shelf(position: position, rowCount: 2, slotsPerRow: 4))
        }
        context.insert(Shelf(position: 6, rowCount: 1, slotsPerRow: 6))
    }
}
