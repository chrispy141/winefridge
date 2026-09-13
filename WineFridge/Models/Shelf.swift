//
//  Shelf.swift
//  WineFridge
//

import Foundation
import SwiftData

@Model
final class Shelf {
    // Every stored property below has a default value (or is optional) so the
    // schema satisfies CloudKit's requirements for SwiftData sync — see
    // https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices.
    /// Display/sort order among all shelves. Kept in sync on add/remove/reorder.
    var position: Int = 0
    /// Stable identity used by `SlotID`, independent of `position` so reordering
    /// shelves never disturbs existing bottle placements.
    var shelfID: UUID = UUID()
    /// Number of bottle slots in each row, ordered front-to-back. Always has
    /// at least one row; rows may hold different numbers of bottles (e.g.
    /// `[3, 4, 5]` for a pyramid-style rack).
    var rowSlotCounts: [Int] = [4, 4]
    /// The `Storage.storageID` of the storage unit this shelf belongs to.
    /// Defaulted so SwiftData can lightweight-migrate stores predating this field.
    var storageID: UUID = UUID()
    /// When true, every row except the bottommost is nudged right by half a
    /// bottle width so its bottles nest between the pair below. Defaulted so
    /// SwiftData can lightweight-migrate stores predating this field.
    var isOffsetRows: Bool = true

    var rowCount: Int { rowSlotCounts.count }

    init(position: Int, rowSlotCounts: [Int] = [4, 4], isOffsetRows: Bool = true, storageID: UUID) {
        self.position = position
        self.shelfID = UUID()
        self.rowSlotCounts = rowSlotCounts
        self.isOffsetRows = isOffsetRows
        self.storageID = storageID
    }

    /// Inserts a storage unit's original fixed layout: six double-row shelves
    /// of 4, plus a single-row shelf of 6 (the old "bottom row"). Only meant
    /// to run once, when a storage unit has no shelves yet.
    static func seedDefaults(in context: ModelContext, storageID: UUID) {
        for position in 0..<6 {
            context.insert(Shelf(position: position, rowSlotCounts: [4, 4], storageID: storageID))
        }
        context.insert(Shelf(position: 6, rowSlotCounts: [6], storageID: storageID))
    }
}
