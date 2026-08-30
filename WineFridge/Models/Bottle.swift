//
//  Bottle.swift
//  WineFridge
//

import Foundation
import SwiftData

@Model
final class Bottle {
    var name: String
    var producer: String
    var wineType: WineType
    var vintage: Int?
    var region: String
    var notes: String
    var dateAdded: Date
    @Attribute(.externalStorage) var photoData: Data?

    private var shelfID: UUID?
    private var row: Int?
    private var column: Int?

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
