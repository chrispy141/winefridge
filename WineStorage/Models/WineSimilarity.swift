//
//  WineSimilarity.swift
//  WineStorage
//

import Foundation

/// Scores how similar two bottles' wine metadata are — used by
/// `WinePlacementService` to decide which existing bottles a newly added one
/// should be placed near. Kept independent of physical storage/distance
/// concerns so it can be tested and tuned on its own.
///
/// Similarity is cumulative: every matching characteristic adds to the
/// score, so a bottle matching several characteristics (producer, grape,
/// appellation, …) attracts far more strongly than one matching only a
/// single weak characteristic. Missing metadata on either bottle simply
/// contributes nothing for that characteristic — it's never treated as a
/// mismatch.
enum WineSimilarity {
    /// Named weights for each characteristic, kept together so the relative
    /// importance of each one is easy to see and retune in one place.
    ///
    /// Geography is intentionally hierarchical: appellation is the most
    /// specific (and strongest) geographic match, region is more general
    /// (and moderate), and country is the most general (and weak) — see
    /// `geoDoubleCountDampening` for how overlap between them is handled.
    enum Weights {
        /// Same wine name/cuvée — the strongest possible match, since it's
        /// close to being the "same wine" as far as storage grouping goes.
        static let cuvee: Double = 6.0
        /// Same producer/winery.
        static let producer: Double = 5.0
        /// Same grape/blend (`Bottle.varietal`).
        static let varietal: Double = 5.0
        /// Same appellation (e.g. "Stags Leap District AVA") — the most
        /// specific geographic match.
        static let appellation: Double = 4.5
        /// Same wine type (red/white/rosé/…).
        static let wineType: Double = 3.0
        /// Same region (e.g. "Napa Valley") — more general than appellation.
        static let region: Double = 2.5
        /// Same designation/tier (e.g. "Reserve").
        static let designation: Double = 1.75
        /// Same country — the most general geographic match.
        static let country: Double = 1.0
        /// The maximum contribution a matching vintage (or a shared
        /// non-vintage designation) can make. Deliberately small relative to
        /// producer/grape/appellation/region — vintage says much less about
        /// which bottles belong together on a shelf.
        static let vintageMax: Double = 1.0
        /// Vintages within this many years of each other contribute a
        /// linearly decaying fraction of `vintageMax`; farther apart than
        /// this contributes nothing.
        static let vintageDecayYears: Int = 6

        /// When a more specific geographic field already matched (e.g.
        /// appellation), a simultaneously matching broader field (region,
        /// country) is largely restating the same fact rather than adding
        /// new independent evidence. This factor scales down that broader
        /// match's contribution so appellation + region + country all
        /// matching doesn't triple-count one geographic fact into an
        /// outsized score.
        static let geoDoubleCountDampening: Double = 0.4
    }

    /// The result of comparing two bottles: a cumulative score, plus the
    /// human-readable characteristics that contributed to it (strongest
    /// first isn't guaranteed here — callers that want ranked reasons
    /// should sort by weight themselves).
    struct Result {
        let score: Double
        let matchedCharacteristics: [String]

        static let none = Result(score: 0, matchedCharacteristics: [])
    }

    /// How similar `a` and `b` are, purely on wine metadata — bottle size
    /// and physical location never factor in here.
    static func similarity(_ a: Bottle, _ b: Bottle) -> Result {
        var score = 0.0
        var characteristics: [String] = []

        func addStringMatch(_ valueA: String, _ valueB: String, weight: Double, label: String) {
            guard let normalizedA = normalized(valueA), normalizedA == normalized(valueB) else { return }
            score += weight
            characteristics.append("\(label): \(valueA)")
        }

        addStringMatch(a.name, b.name, weight: Weights.cuvee, label: "Same Wine/Cuvée")
        addStringMatch(a.producer, b.producer, weight: Weights.producer, label: "Same Producer")
        addStringMatch(a.varietal, b.varietal, weight: Weights.varietal, label: "Same Grape/Blend")
        addStringMatch(a.designation, b.designation, weight: Weights.designation, label: "Same Designation")

        // Unlike the free-text fields above, `wineType` is a non-optional
        // enum — but its "Unknown" case plays the same role a blank string
        // would, so two unknown-style bottles shouldn't count as a match.
        if a.wineType == b.wineType && a.wineType != .unknown {
            score += Weights.wineType
            characteristics.append("Same Type: \(a.wineType.rawValue)")
        }

        let appellationMatches = matches(a.appellation, b.appellation)
        let regionMatches = matches(a.region, b.region)
        let countryMatches = matches(a.country, b.country)

        if appellationMatches {
            score += Weights.appellation
            characteristics.append("Same Appellation: \(a.appellation)")
        }
        if regionMatches {
            score += appellationMatches ? Weights.region * Weights.geoDoubleCountDampening : Weights.region
            characteristics.append("Same Region: \(a.region)")
        }
        if countryMatches {
            let moreSpecificAlreadyMatched = appellationMatches || regionMatches
            score += moreSpecificAlreadyMatched ? Weights.country * Weights.geoDoubleCountDampening : Weights.country
            characteristics.append("Same Country: \(a.country)")
        }

        // Vintage contributes only a small, decaying amount, and two
        // deliberately non-vintage wines count as a (weak) vintage match
        // rather than being skipped as "missing".
        if a.isNonVintage && b.isNonVintage {
            score += Weights.vintageMax
            characteristics.append("Both Non-Vintage")
        } else if let vintageA = a.vintage, let vintageB = b.vintage {
            let diff = abs(vintageA - vintageB)
            if diff < Weights.vintageDecayYears {
                score += Weights.vintageMax * (1 - Double(diff) / Double(Weights.vintageDecayYears))
                if diff == 0 {
                    characteristics.append("Same Vintage: \(vintageA)")
                }
            }
        }

        return Result(score: score, matchedCharacteristics: characteristics)
    }

    private static func matches(_ a: String, _ b: String) -> Bool {
        guard let normalizedA = normalized(a) else { return false }
        return normalizedA == normalized(b)
    }

    /// Trims and lowercases free-text metadata so comparisons aren't thrown
    /// off by case or incidental whitespace (matching the normalization
    /// `AutocompleteTextField` already applies to these same fields).
    /// Returns `nil` for empty/missing values so callers can treat them as
    /// "no contribution" rather than an empty-string match.
    private static func normalized(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed.lowercased()
    }
}
