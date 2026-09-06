//
//  Storage.swift
//  WineFridge
//

import Foundation
import SwiftData

@Model
final class Storage {
    // Every stored property below has a default value (or is optional) so the
    // schema satisfies CloudKit's requirements for SwiftData sync — see
    // https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices.
    var name: String = ""
    /// Display/sort order among all storage units.
    var position: Int = 0
    var dateCreated: Date = Date.now
    /// Stable identity referenced by `Shelf.storageID`, independent of
    /// `position` so reordering storage units never disturbs shelf ownership.
    var storageID: UUID = UUID()
    /// Optional (rather than defaulted) so stores predating this field don't
    /// crash: SwiftData's lightweight migration doesn't backfill a Swift-level
    /// default for custom enum attributes, so a missing value must decode to
    /// `nil` rather than force-cast into a non-optional `FridgeIcon`.
    var icon: FridgeIcon?

    /// The icon to display — falls back to `.tall` for storage units created
    /// before this field existed.
    var displayIcon: FridgeIcon { icon ?? .tall }

    init(name: String, position: Int, icon: FridgeIcon = .tall, dateCreated: Date = .now) {
        self.name = name
        self.position = position
        self.dateCreated = dateCreated
        self.storageID = UUID()
        self.icon = icon
    }
}
