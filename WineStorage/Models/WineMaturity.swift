//
//  WineMaturity.swift
//  WineStorage
//

import SwiftUI
import UIKit

/// Where a wine sits in its drinking-window aging lifecycle. This is a
/// classification of *estimated drinking quality*, not strict drinkability —
/// a developing wine may already be enjoyable, and a past-peak wine may
/// still be excellent. See `WineMaturity` for the continuous math these
/// discrete stages are derived from.
enum WineMaturityStage: CaseIterable, Identifiable {
    case developing
    case approachingPeak
    case atPeak
    case pastPeak

    var id: Self { self }

    /// A fixed (non-dynamic) color — chosen to stay clearly distinguishable
    /// from one another in both light and dark mode without needing
    /// separate appearance-specific variants.
    var color: Color {
        switch self {
        case .developing: Color(hex: 0x648DB5)
        case .approachingPeak: Color(hex: 0xE3B341)
        case .atPeak: Color(hex: 0x3D9B68)
        case .pastPeak: Color(hex: 0xC45A58)
        }
    }

    /// Short label for the legend and inline badges.
    var label: String {
        switch self {
        case .developing: "Developing"
        case .approachingPeak: "Near Peak"
        case .atPeak: "At Peak"
        case .pastPeak: "Past Peak"
        }
    }

    /// A fuller description for VoiceOver (and anywhere else maturity needs
    /// to be conveyed without relying on color alone).
    var accessibilityDescription: String {
        switch self {
        case .developing:
            "Developing. Still maturing — hasn't reached its optimal drinking period yet, though it may already be enjoyable."
        case .approachingPeak:
            "Approaching peak. Nearing its optimal drinking period."
        case .atPeak:
            "At peak. Within its optimal drinking period — an ideal time to enjoy it."
        case .pastPeak:
            "Past peak. Its estimated optimal drinking period has passed — consider prioritizing it, though it may still be excellent."
        }
    }
}

/// The shared math behind the drinking-window maturity visualization: where
/// a given year falls in a bottle's `[startYear, endYear]` aging window.
/// Drives both the discrete `WineMaturityStage` and the continuous color
/// blend / opacity intensity shown in `DrinkWindowTimelineView`, so the two
/// are always derived from the same boundaries.
enum WineMaturity {
    /// Reach full ramp-in by 35% into the window; begin ramping out at 70%.
    /// The plateau between them is `.atPeak` — not necessarily the window's
    /// exact midpoint, since the two spans need not be equal.
    private static let rampInFraction = 0.35
    private static let rampOutStart = 0.70

    private static func smoothstep(_ t: Double) -> Double {
        let x = min(1, max(0, t))
        return x * x * (3 - 2 * x)
    }

    /// `fadeIn` ramps 0...1 across the first `rampInFraction` of the window
    /// and clamps to 0/1 outside it; `fadeOut` ramps 1...0 across the last
    /// `1 - rampOutStart` of it and clamps likewise. When `holdAtPeak` is
    /// set — an open-ended window with no known end year — `fadeOut` is
    /// pinned to 1 so neither color nor opacity ever reads as declining,
    /// since there's nothing to decline toward.
    static func phase(year: Double, startYear: Double, endYear: Double, holdAtPeak: Bool) -> (fadeIn: Double, fadeOut: Double) {
        let duration = max(1, endYear - startYear)
        let progress = (year - startYear) / duration
        let fadeIn = smoothstep(progress / rampInFraction)
        let fadeOut = holdAtPeak ? 1 : smoothstep((1 - progress) / (1 - rampOutStart))
        return (fadeIn, fadeOut)
    }

    /// How "in the zone" a given year is — 0 outside the window, ramping up
    /// to 1 through the ramp-in, holding at 1 through the plateau, then
    /// easing back down to 0 through the ramp-out. This drives opacity
    /// only; maturity *color* comes from `stage`/`color` below.
    static func intensity(fadeIn: Double, fadeOut: Double) -> Double {
        min(fadeIn, fadeOut)
    }

    /// The discrete stage for a given phase, using the exact same ramp-in/
    /// ramp-out boundaries as `intensity`.
    static func stage(fadeIn: Double, fadeOut: Double) -> WineMaturityStage {
        if fadeOut < 1 { return .pastPeak }
        if fadeIn >= 1 { return .atPeak }
        return fadeIn < 0.5 ? .developing : .approachingPeak
    }

    /// Convenience for callers that just want "what stage is this bottle in
    /// right now" from its raw, possibly-partial drinking window — e.g. a
    /// detail view showing a single maturity badge rather than a timeline.
    /// A missing start is treated as "ready as of `year`"; a missing end
    /// holds at peak once reached (see `phase`). `nil` when neither bound
    /// is set, matching `Bottle.drinkWindowDisplayText`.
    static func stage(start: Int?, end: Int?, asOf year: Int) -> WineMaturityStage? {
        guard start != nil || end != nil else { return nil }
        let startYear = Double(start ?? year)
        let endYear = Double(end.map { Swift.max($0, start ?? year) } ?? year + 1)
        let phase = phase(year: Double(year), startYear: startYear, endYear: endYear, holdAtPeak: end == nil)
        return stage(fadeIn: phase.fadeIn, fadeOut: phase.fadeOut)
    }

    /// A continuous blend across all four stage colors — Blue → Yellow →
    /// Green → Red — so a bar reads as one smooth gradient even though
    /// `stage` buckets it discretely. The blend lands exactly on each
    /// stage's color at that stage's boundary, so there's no visible seam
    /// where this meets a neighboring sample: the ramp-in sweeps
    /// developing → approaching → atPeak as `fadeIn` goes 0 → 1 (reaching
    /// atPeak's color exactly as the plateau begins), and the ramp-out
    /// sweeps atPeak → pastPeak as `fadeOut` goes 1 → 0.
    static func color(fadeIn: Double, fadeOut: Double) -> Color {
        if fadeOut < 1 {
            return lerp(WineMaturityStage.atPeak.color, WineMaturityStage.pastPeak.color, 1 - fadeOut)
        }
        let t = min(max(fadeIn, 0), 1)
        if t < 0.5 {
            return lerp(WineMaturityStage.developing.color, WineMaturityStage.approachingPeak.color, t / 0.5)
        } else {
            return lerp(WineMaturityStage.approachingPeak.color, WineMaturityStage.atPeak.color, (t - 0.5) / 0.5)
        }
    }

    /// `color` pre-blended at `opacity` over a white backdrop, flattened
    /// into one opaque color. A swatch that instead applied `.opacity()`
    /// directly would look different depending on whatever happened to be
    /// behind it (e.g. a List row background vs. a plain view background),
    /// so callers showing a fixed representative sample of a stage that's
    /// only ever seen at a reduced opacity (`developing`/`pastPeak`, which
    /// sit at the intensity floor) use this instead to guarantee a match.
    static func flattened(_ color: Color, opacity: Double, over background: Color = .white) -> Color {
        let (r, g, b) = rgbComponents(color)
        let (br, bg, bb) = rgbComponents(background)
        return Color(
            red: r * opacity + br * (1 - opacity),
            green: g * opacity + bg * (1 - opacity),
            blue: b * opacity + bb * (1 - opacity)
        )
    }

    private static func rgbComponents(_ color: Color) -> (Double, Double, Double) {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Double(r), Double(g), Double(b))
    }

    private static func lerp(_ a: Color, _ b: Color, _ t: Double) -> Color {
        let (ar, ag, ab) = rgbComponents(a)
        let (br, bg, bb) = rgbComponents(b)
        return Color(red: ar + (br - ar) * t, green: ag + (bg - ag) * t, blue: ab + (bb - ab) * t)
    }
}

private extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
