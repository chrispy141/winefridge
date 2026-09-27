//
//  BottleSize.swift
//  WineStorage
//

import Foundation

enum BottleSize: String, Codable, CaseIterable, Identifiable {
    case quarter = "Quarter (187 mL)"
    case half = "Half (375 mL)"
    case standard = "Standard (750 mL)"
    case magnum = "Magnum (1.5 L)"
    case doubleMagnum = "Double Magnum (3 L)"

    var id: String { rawValue }
}
