//
//  WineLabelInfo.swift
//  WineStorage
//

import FoundationModels

/// The structured shape the on-device Foundation Model fills in when
/// interpreting OCR text recognized from a wine label (see
/// `WineLabelInterpreter`). Every property is optional so the model can
/// leave a field blank instead of inventing a value it isn't confident
/// about.
@available(iOS 26.0, *)
@Generable
struct WineLabelInfo {
    @Guide(description: "The winery or producer name printed on the label, e.g. 'Stag's Leap Wine Cellars'. Leave blank if it isn't clearly stated.")
    var producer: String?

    @Guide(description: "The specific named wine or cuvée within the producer's lineup, e.g. 'CASK 23'. This is distinct from the producer name and the grape variety. Leave blank if the label doesn't name a specific wine.")
    var wineName: String?

    @Guide(description: "A designation or tier term printed on the label, such as Reserve, Estate, Grand Reserve, or Special Selection. Leave blank if none is stated.")
    var designation: String?

    @Guide(description: "The grape variety or blend actually printed on the label, e.g. a single variety like 'Sangiovese' or a blend like 'Grenache, Syrah, Mourvèdre'. These are only examples of the expected format — never default to one of them, or to any other well-known grape, when the label doesn't clearly support it. Leave blank if it isn't stated or unambiguous.")
    var varietal: String?

    @Guide(description: "The wine's style: Red, White, Rosé, Sparkling, Dessert, or Fortified. Choose this only when the label states it directly, or when the Grape/Blend field names a variety whose color is unambiguous. Leave blank if it's unclear.")
    var wineType: String?

    @Guide(description: "The four-digit vintage year, but only if that literal year is printed on the label, e.g. 2022. Never guess a typical or likely vintage. Leave blank if no year is printed in the text, including when the label instead marks the wine as non-vintage.")
    var vintage: Int?

    @Guide(description: "True if the label explicitly marks the wine as non-vintage — printing 'NV' or 'Non-Vintage' in place of a year. Must be false whenever a vintage year is also reported below, since a printed year and non-vintage are mutually exclusive. Leave blank if the label doesn't clearly address this either way.")
    var isNonVintage: Bool?

    @Guide(description: "The country of origin, e.g. 'United States' or 'France'. Leave blank if it isn't stated or confidently inferable.")
    var country: String?

    @Guide(description: "The broader recognized wine region, e.g. 'Napa Valley' or 'Bordeaux'. Leave blank if it isn't stated.")
    var region: String?

    @Guide(description: "The legally recognized geographic appellation, e.g. 'Stags Leap District AVA', 'Pauillac AOC', or 'Barolo DOCG'. Leave blank if it isn't stated.")
    var appellation: String?

    @Guide(description: "A specific named vineyard or vineyards credited on the label, e.g. 'S.L.V. & FAY Vineyards'. Leave blank if none is named.")
    var vineyard: String?

    @Guide(description: "The bottle size in milliliters, only if it's explicitly printed on the label, e.g. 750, 375, 1500, or 3000. Leave blank if it isn't stated.")
    var bottleSizeMilliliters: Int?

    @Guide(description: "The alcohol by volume percentage, but only if a specific number is printed on the label (typically next to 'ALC', 'ALC/VOL', or a '%' sign), e.g. 14.8. Never estimate or fill in a typical percentage for the wine's style, grape, or region. Leave blank if no percentage is printed in the text.")
    var abv: Double?
}
