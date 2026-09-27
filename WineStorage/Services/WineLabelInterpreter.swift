//
//  WineLabelInterpreter.swift
//  WineStorage
//

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
        You are a wine-label parser. You're given text recognized from a photo of a wine \
        label using on-device OCR; the text may be noisy, out of order, or missing characters.

        Extract only the fields that are clearly supported by the label text, distinguishing \
        carefully between:
        - Producer: the winery or producer.
        - Wine / Cuvée: the specific named wine within the producer's lineup — distinct from \
        the producer name and from the grape variety.
        - Designation / Tier: terms like Reserve, Estate, Grand Reserve, or Special Selection.
        - Grape / Blend: the grape variety or blend.
        - Type: the wine's style, choosing only from the given options.
        - Region: the broader recognized wine region.
        - Appellation: the legally recognized geographic designation, such as \
        "Stags Leap District AVA", "Pauillac AOC", or "Barolo DOCG".
        - Vineyard: a specific named vineyard or vineyards.
        - Vintage: the year printed on the label, if any. Some wines are deliberately \
        non-vintage instead of printing a year — the label says "NV" or "Non-Vintage" — \
        report that separately rather than guessing a year. These are mutually exclusive: \
        if any year is printed on the label, isNonVintage must be false, even if the label \
        also happens to include other phrasing you might otherwise associate with \
        non-vintage wines.

        Each field's description includes "e.g." examples showing the expected format only — \
        they are not likely or default answers. Never copy an example into your answer, or \
        fall back to some other common producer, grape, region, etc., merely because the label \
        text is unclear. Leave a field blank instead.

        You may make safe semantic deductions about categories, such as recognizing the color \
        implied by a grape variety that's unambiguously one color. You must NOT estimate or fill in specific numeric or \
        factual details — such as vintage, ABV, appellation, or vineyard — using typical or \
        likely values for the wine's style, producer, or region. Only report a vintage or ABV \
        if that literal number is printed in the text. Leave a field blank rather than guess, \
        even when a plausible-sounding value would usually be correct.
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

        return WineLabelExtraction(
            producer: info.producer,
            wineName: info.wineName,
            designation: info.designation,
            varietal: info.varietal,
            wineType: info.wineType.flatMap(WineType.init(rawValue:)),
            vintage: vintage,
            isNonVintage: isNonVintage,
            country: info.country,
            region: info.region,
            appellation: info.appellation,
            vineyard: info.vineyard,
            bottleSize: info.bottleSizeMilliliters.flatMap(bottleSize(forMilliliters:)),
            abv: info.abv
        )
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
