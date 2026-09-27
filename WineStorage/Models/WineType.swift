//
//  WineType.swift
//  WineStorage
//

import SwiftUI

enum WineType: String, Codable, CaseIterable, Identifiable {
    case unknown = "Unknown"
    case red = "Red"
    case white = "White"
    case rose = "Rosé"
    case sparkling = "Sparkling"
    case dessert = "Dessert"
    case fortified = "Fortified"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .unknown: return .gray
        case .red: return .red
        case .white: return .yellow
        case .rose: return .pink
        case .sparkling: return .mint
        case .dessert: return .orange
        case .fortified: return .brown
        }
    }
}
