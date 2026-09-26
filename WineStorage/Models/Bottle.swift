//
//  Bottle.swift
//  WineStorage
//

import Foundation
import SwiftData

@Model
final class Bottle {
    // Every stored property below has a default value (or is optional) so the
    // schema satisfies CloudKit's requirements for SwiftData sync — see
    // https://developer.apple.com/documentation/swiftdata/syncing-model-data-across-a-persons-devices.
    var name: String = ""
    var producer: String = ""
    var wineType: WineType = WineType.red
    var vintage: Int?
    var region: String = ""
    var notes: String = ""
    var dateAdded: Date = Date.now
    @Attribute(.externalStorage) var photoData: Data?

    private var shelfID: UUID?
    private var row: Int?
    private var column: Int?

    /// A bottle has no storage unit of its own — it's storage-agnostic until
    /// placed on a shelf slot (see `slot`), at which point its storage unit
    /// is whichever one owns that shelf. Removing it from the shelf returns
    /// it to the shared, storage-agnostic inventory.
    init(
        name: String,
        producer: String = "",
        wineType: WineType = .red,
        vintage: Int? = nil,
        region: String = "",
        notes: String = "",
        dateAdded: Date = .now,
        slot: SlotID? = nil,
        photoData: Data? = nil
    ) {
        self.name = name
        self.producer = producer
        self.wineType = wineType
        self.vintage = vintage
        self.region = region
        self.notes = notes
        self.dateAdded = dateAdded
        self.shelfID = slot?.shelfID
        self.row = slot?.row
        self.column = slot?.column
        self.photoData = photoData
    }

    /// The slot this bottle currently occupies, or `nil` if it hasn't been placed on a shelf.
    var slot: SlotID? {
        get {
            guard let shelfID, let row, let column else {
                return nil
            }
            return SlotID(shelfID: shelfID, row: row, column: column)
        }
        set {
            shelfID = newValue?.shelfID
            row = newValue?.row
            column = newValue?.column
        }
    }

    func clearSlot() {
        slot = nil
    }
}
