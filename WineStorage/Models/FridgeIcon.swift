//
//  FridgeIcon.swift
//  WineStorage
//

enum FridgeIcon: String, Codable, CaseIterable, Identifiable {
    case small = "FridgeIconSmall"
    case tall = "FridgeIconTall"
    case shelfOne = "ShelfIconOne"
    case shelfTwo = "ShelfIconTwo"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .small: return "Small Fridge"
        case .tall: return "Tall Fridge"
        case .shelfOne: return "Cellar Shelf 1"
        case .shelfTwo: return "Cellar Shelf 2"
        }
    }

    /// The asset catalog image name.
    var imageName: String { rawValue }
}
