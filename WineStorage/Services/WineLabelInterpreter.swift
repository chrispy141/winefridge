//
//  WineLabelInterpreter.swift
//  WineStorage
//

import Foundation
import FoundationModels

/// Interprets OCR text recognized from a wine label using Apple's on-device
/// Foundation Model, producing structured wine information.
///
/// This is kept separate from `WineLabelTextRecognizer` (the Vision/OCR
/// layer) so each stage of the pipeline can be tested independently: this
/// type only ever deals with text in, structured data out.
@available(iOS 26.0, *)
struct WineLabelInterpreter {
    /// Whether the on-device model is ready to interpret label text right now.
    static func availability() -> SystemLanguageModel.Availability {
        SystemLanguageModel.default.availability
    }

    /// A human-readable explanation for why interpretation isn't available,
    /// suitable for showing directly to someone using the app.
    static func describe(_ reason: SystemLanguageModel.Availability.UnavailableReason) -> String {
        switch reason {
        case .deviceNotEligible:
            return "This device doesn't support Apple Intelligence, so label details can't be filled in automatically."
        case .appleIntelligenceNotEnabled:
            return "Turn on Apple Intelligence in Settings to automatically fill in label details from a photo."
        case .modelNotReady:
            return "The on-device model is still downloading or getting ready. Try scanning again in a bit."
        @unknown default:
            return "Intelligent label interpretation isn't available on this device right now."
        }
    }

    /// Interprets recognized label text into structured wine information.
    /// Callers should check `availability()` first.
    func interpret(ocrText: String) async throws -> WineLabelExtraction {
        let session = LanguageModelSession(instructions: Self.instructions)
        let response = try await session.respond(
            to: "Wine label text, as recognized by on-device OCR (line breaks may fall in odd places):\n\n\(ocrText)",
            generating: WineLabelInfo.self
        )
        return Self.extraction(from: response.content)
    }

    private static let instructions = """
        You are a wine-label parser. You're given text recognized from a photo of a wine label using on-device OCR; the text may be noisy, out of order, or missing characters.

        Extract only the fields that are clearly supported by the label text, distinguishing carefully between:

        - Producer: the winery or producer.
        - Wine / Cuvée: the specific named wine within the producer's lineup — distinct from the producer name and from the grape variety.
        - Designation / Tier: terms like Reserve, Estate, Grand Reserve, or Special Selection.
        - Grape / Blend: the grape variety or blend.
        - Type: the wine's broad style, choosing only from the provided Type options.
        - Region: the broader recognized wine region.
        - Appellation: the legally recognized geographic designation, such as "Stags Leap District AVA", "Pauillac AOC", or "Barolo DOCG".
        - Vineyard: a specific named vineyard or vineyards.
        - Vintage: the year printed on the label, if any. Some wines are deliberately non-vintage instead of printing a year — the label says "NV" or "Non-Vintage" — report that separately rather than guessing a year. These are mutually exclusive: if any year is printed on the label, isNonVintage must be false, even if the label also happens to include other phrasing you might otherwise associate with non-vintage wines.
        - ABV: Alcohol by Volume percentage. Only populate this field when the label text explicitly contains an alcohol percentage written as a whole or decimal number followed by a percent sign (%), such as 14% or 14.5%. Do not infer, estimate, or guess ABV based on the wine's producer, grape, type, region, appellation, vintage, or typical alcohol level. If no explicit numeric percentage is present in the recognized label text, leave ABV blank. Do not populate as 0.0 if it is unknown but leave blank. 

        Each field's description includes "e.g." examples showing the expected format only — they are not likely or default answers. Never copy an example into your answer, or fall back to some other common producer, grape, region, etc., merely because the label text is unclear. Leave a field blank instead.

        TYPE CLASSIFICATION:

        Unlike specific factual fields such as vintage, ABV, vineyard, or appellation, Type may be inferred when the recognized grape variety or well-established wine style makes the type unambiguous. The label does not need to literally contain the words "Red", "White", etc.

        Use these common examples as classification guidance, not as values to copy into other fields:

        - Red: Cabernet Sauvignon, Merlot, Cabernet Franc, Pinot Noir, Syrah/Shiraz, Grenache, Malbec, Nebbiolo, Sangiovese, Tempranillo, Zinfandel, Barbera, Gamay, Petite Sirah, Mourvèdre, and typical red Bordeaux, Rhône, Rioja, Chianti, Brunello, Barolo, and red Burgundy wines.

        - White: Chardonnay, Sauvignon Blanc, Riesling, Pinot Grigio/Pinot Gris, Chenin Blanc, Gewürztraminer, Viognier, Albariño, Grüner Veltliner, Sémillon, Muscadet/Melon de Bourgogne, and typical still white Burgundy, white Bordeaux, and Sancerre.

        - Sparkling: Champagne, Prosecco, Cava, Crémant, Franciacorta, Sekt, Asti, sparkling wine, and wines explicitly identified as sparkling, spumante, or méthode/traditional-method sparkling wine. A sparkling wine should be classified as Sparkling rather than White or Rosé unless the available Type options explicitly distinguish sparkling rosé.

        - Rosé: wines explicitly identified as Rosé, Rosado, Rosato, or other clearly recognized rosé styles. Do not classify a wine as Rosé merely because it uses a red grape variety.

        - Dessert: wines clearly identified as late-harvest, ice wine/Eiswein, Sauternes, Barsac, Beerenauslese, Trockenbeerenauslese, Tokaji Aszú, Vin Santo, Passito, or another clearly sweet dessert-wine style. Do not classify a wine as Dessert merely because its grape variety is sometimes used to make sweet wine.

        - Fortified: Port/Porto, Sherry/Jerez, Madeira, Marsala, Vermouth, Banyuls, Maury, and other wines clearly identified as fortified. If a wine is both sweet and fortified, classify it as Fortified rather than Dessert when only one Type may be selected.

        When classifying Type, prioritize explicit style terminology over inference from grape variety.

        For example:
        - "Cabernet Sauvignon" with no contradictory style information → Red.
        - "Chardonnay" with no contradictory style information → White.
        - "Champagne" → Sparkling, even though it may be made from Chardonnay or Pinot Noir.
        - "Prosecco" → Sparkling.
        - "White Zinfandel" → Rosé, not Red.
        - "Sauternes" → Dessert, not simply White.
        - "Port" → Fortified, not simply Red or Dessert.
        - "Sherry" → Fortified, even when the particular Sherry is dry.
        - "Blanc de Noirs Champagne" → Sparkling, not Red, despite being made from red grapes.

        If the grape or terminology does not establish Type with reasonable confidence, leave Type blank rather than guessing.

        You may make safe semantic deductions about categories, such as recognizing the wine Type implied by an unambiguous grape variety or established wine style. You must NOT estimate or fill in specific numeric or factual details — such as vintage, ABV, appellation, or vineyard — using typical or likely values for the wine's style, producer, or region. Only report a vintage or ABV if that literal number is printed in the text. Leave a field blank rather than guess, even when a plausible-sounding value would usually be correct.
        """

    private static func extraction(from info: WineLabelInfo) -> WineLabelExtraction {
        // The model sometimes emits `0` for `vintage` instead of leaving it
        // blank when no year is printed — treat that (or any non-positive
        // value) as "no vintage" rather than a literal year.
        let vintage = (info.vintage ?? 0) > 0 ? info.vintage : nil

        // It can also report `isNonVintage: true` alongside a clearly-printed
        // vintage year — a self-contradiction it shouldn't be able to make,
        // but which would otherwise cause the (correct) year to get
        // discarded downstream in favor of "NV". A real printed year always
        // wins.
        let isNonVintage = vintage == nil ? info.isNonVintage : false

        // The model sometimes emits `0` for `abv` instead of leaving it
        // blank when no percentage is printed, and can't produce a
        // negative or absurdly high percentage from real label text —
        // treat any such value as "no ABV" rather than a literal reading.
        let abv = info.abv.flatMap { $0 > 0 && $0 < 100 ? $0 : nil }

        return WineLabelExtraction(
            producer: titleCased(info.producer),
            wineName: titleCased(info.wineName),
            designation: titleCased(info.designation),
            varietal: titleCased(info.varietal),
            wineType: info.wineType.flatMap(WineType.init(rawValue:)),
            vintage: vintage,
            isNonVintage: isNonVintage,
            country: titleCased(info.country),
            region: titleCased(info.region),
            appellation: titleCased(info.appellation),
            vineyard: titleCased(info.vineyard),
            bottleSize: info.bottleSizeMilliliters.flatMap(bottleSize(forMilliliters:)),
            abv: abv
        )
    }

    /// Words that stay lowercase in title case unless they lead the string,
    /// e.g. "Château Val de Vie" or "Château du Tertre".
    private static let lowercaseConnectors: Set<String> = [
        "de", "du", "des", "la", "le", "les", "di", "del", "della", "dei",
        "y", "et", "and", "of", "the", "in", "sur", "van", "von", "der",
        "da", "do", "das", "dos"
    ]

    /// Recognized abbreviations that should stay fully uppercase rather
    /// than being title-cased, e.g. "Barolo DOCG" or "Pauillac AOC".
    private static let preservedAcronyms: Set<String> = [
        "AVA", "AOC", "AOP", "DOC", "DOCG", "IGT", "IGP", "VDP", "QBA",
        "AC", "VDQS", "DO", "DOP", "NV"
    ]

    /// Normalizes label text pulled from OCR — which is often printed in
    /// all caps on the label itself — into standard title case, so the form
    /// doesn't get pre-filled with shouted-looking text.
    private static func titleCased(_ text: String?) -> String? {
        guard let text else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }
        return trimmed
            .split(separator: " ", omittingEmptySubsequences: false)
            .enumerated()
            .map { index, word in titleCasedWord(String(word), isFirst: index == 0) }
            .joined(separator: " ")
    }

    private static func titleCasedWord(_ word: String, isFirst: Bool) -> String {
        guard !word.isEmpty else { return word }
        let upper = word.uppercased()
        if preservedAcronyms.contains(upper) {
            return upper
        }
        let lower = word.lowercased()
        if !isFirst && lowercaseConnectors.contains(lower) {
            return lower
        }
        return lower.prefix(1).uppercased() + lower.dropFirst()
    }

    private static nonisolated func bottleSize(forMilliliters milliliters: Int) -> BottleSize? {
        switch milliliters {
        case 187: return .quarter
        case 375: return .half
        case 750: return .standard
        case 1500: return .magnum
        case 3000: return .doubleMagnum
        default: return nil
        }
    }
}
