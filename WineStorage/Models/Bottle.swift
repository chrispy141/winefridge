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
    /// The wine's name or cuvée (e.g. "Reserve") — distinguishes bottlings
    /// within a producer's lineup. The one required field.
    var name: String = ""
    var producer: String = ""
    var wineType: WineType = WineType.red
    var varietal: String = ""
    var vintage: Int?
    /// Whether this bottle is a deliberately non-vintage ("NV") wine, as
    /// opposed to `vintage` simply being unknown. Never set alongside a
    /// non-nil `vintage` — see `vintageSelection`, which enforces that.
    var isNonVintage: Bool = false
    var country: String = ""
    var region: String = ""
    var appellation: String = ""
    var vineyard: String = ""
    var designation: String = ""
    var bottleSize: BottleSize = BottleSize.standard
    var abv: Double?
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
        varietal: String = "",
        vintage: Int? = nil,
        isNonVintage: Bool = false,
        country: String = "",
        region: String = "",
        appellation: String = "",
        vineyard: String = "",
        designation: String = "",
        bottleSize: BottleSize = .standard,
        abv: Double? = nil,
        notes: String = "",
        dateAdded: Date = .now,
        slot: SlotID? = nil,
        photoData: Data? = nil
    ) {
        self.name = name
        self.producer = producer
        self.wineType = wineType
        self.varietal = varietal
        self.vintage = vintage
        self.isNonVintage = isNonVintage
        self.country = country
        self.region = region
        self.appellation = appellation
        self.vineyard = vineyard
        self.designation = designation
        self.bottleSize = bottleSize
        self.abv = abv
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

    /// A friendlier, exhaustive view of `vintage`/`isNonVintage` for UI code
    /// (see the vintage picker in `BottleFormView`) that can't express the
    /// invalid combination of both a year and `isNonVintage` being set.
    enum VintageSelection: Hashable {
        case unknown
        case nonVintage
        case year(Int)
    }

    var vintageSelection: VintageSelection {
        get {
            if isNonVintage {
                return .nonVintage
            }
            if let vintage {
                return .year(vintage)
            }
            return .unknown
        }
        set {
            switch newValue {
            case .unknown:
                vintage = nil
                isNonVintage = false
            case .nonVintage:
                vintage = nil
                isNonVintage = true
            case .year(let year):
                vintage = year
                isNonVintage = false
            }
        }
    }

    /// A short label for displaying the vintage, or `nil` when it's unknown
    /// (matching how `vintage == nil` is already handled everywhere it's
    /// displayed today).
    var vintageDisplayText: String? {
        switch vintageSelection {
        case .unknown: return nil
        case .nonVintage: return "NV"
        case .year(let year): return String(year)
        }
    }
}
