//
//  WineLabelExtraction.swift
//  WineStorage
//

import Foundation

/// Wine information extracted from a label photo, ready to pre-populate the
/// bottle form. Every field is optional — the extraction should leave a
/// field blank rather than guess when the label doesn't clearly support it.
///
/// This is a plain, always-available type so `BottleFormView` can consume it
/// without depending on the FoundationModels-only APIs that produce it (see
/// `WineLabelInterpreter`), which require iOS 26.
struct WineLabelExtraction {
    var producer: String?
    var wineName: String?
    var designation: String?
    var varietal: String?
    var wineType: WineType?
    var vintage: Int?
    /// Whether the label explicitly marks the wine as non-vintage ("NV"),
    /// rather than simply not stating a vintage year at all.
    var isNonVintage: Bool?
    var country: String?
    var region: String?
    var appellation: String?
    var vineyard: String?
    var bottleSize: BottleSize?
    var abv: Double?
}
