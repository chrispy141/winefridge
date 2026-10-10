//
//  FridgeIcon.swift
//  WineStorage
//

enum FridgeIcon: String, Codable, CaseIterable, Identifiable {
    case small = "FridgeIconSmall"
    case tall = "FridgeIconTall"
    case shelfSmall = "SmallShelfIcon"
    case shelfLarge = "LargeShelfIcon"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .small: return "Small Fridge"
        case .tall: return "Large Fridge"
        case .shelfSmall: return "Small Shelf"
        case .shelfLarge: return "Large Shelf"
        }
    }

    /// The asset catalog image name.
    var imageName: String { rawValue }
}
