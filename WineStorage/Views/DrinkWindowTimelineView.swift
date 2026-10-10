//
//  DrinkWindowTimelineView.swift
//  WineStorage
//

import SwiftUI

/// A compact horizontal timeline for a bottle's drinking window, shown inline
/// in the inventory list. Every bottle shares the same timeline domain — the
/// left edge is always today, and the right edge is `horizonYear` (chosen
/// once, above the whole list), so bars are directly comparable. The bar is
/// a stoplight: red outside the window, smoothly shifting through yellow as
/// it ramps up or down, and solid green at peak drinking (see `intensity`).
/// Bottles whose window has already closed are shown as a solid red bar
/// instead, signaling it's overdue.
struct DrinkWindowTimelineView: View {
    let bottle: Bottle
    let horizonYear: Int

    private static let height: CGFloat = 6
    /// Number of gradient stops sampled across the visible domain to
    /// approximate the smoothstep curve from `intensity`.
    private static let sampleCount = 24

    private var currentYear: Int {
        Calendar.current.component(.year, from: .now)
    }

    private var isOverdue: Bool {
        guard let end = bottle.drinkWindowEndYear else { return false }
        return end < currentYear
    }

    var body: some View {
        if isOverdue {
            Capsule()
                .fill(Color.red.opacity(0.85))
                .frame(height: Self.height)
        } else if let stops = gradientStops {
            Capsule()
                .fill(LinearGradient(stops: stops, startPoint: .leading, endPoint: .trailing))
                .frame(height: Self.height)
        }
    }

    /// Builds the stoplight gradient for the bar over the fixed
    /// `[today, horizonYear]` domain by sampling `intensity` at evenly spaced
    /// years, or `nil` when there's no window to show. A missing start is
    /// treated as "ready as of today"; a missing end has no real fade-out
    /// point, so the ramp is given a nominal span to climb across and then
    /// held at its peak (via a running maximum) instead of fading back down.
    private var gradientStops: [Gradient.Stop]? {
        let start = bottle.drinkWindowStartYear
        let end = bottle.drinkWindowEndYear
        guard start != nil || end != nil else { return nil }

        let domainStart = Double(currentYear)
        let domainEnd = Double(max(horizonYear, currentYear + 1))
        let startYear = Double(start ?? currentYear)
        let endYear = Double(end.map { Swift.max($0, start ?? currentYear) } ?? Int(domainEnd))
        let holdAtPeak = end == nil

        let span = domainEnd - domainStart

        var runningPeak = 0.0
        return (0...Self.sampleCount).map { index in
            let location = Double(index) / Double(Self.sampleCount)
            let year = domainStart + location * span
            var intensity = Self.intensity(year: year, startYear: startYear, endYear: endYear)
            if holdAtPeak {
                runningPeak = max(runningPeak, intensity)
                intensity = runningPeak
            }
            let opacity = 0.15 + 0.85 * intensity
            return Gradient.Stop(color: Self.stoplightColor(intensity: intensity).opacity(opacity), location: location)
        }
    }

    /// How "in the zone" a given year is: 0 outside the window, ramping up
    /// to 1 by 35% into the window, holding until 70%, then easing back
    /// down to 0 by `endYear`.
    private static func intensity(
        year: Double,
        startYear: Double,
        endYear: Double
    ) -> Double {
        let duration = max(1, endYear - startYear)
        let progress = (year - startYear) / duration

        func smoothstep(_ t: Double) -> Double {
            let x = min(1, max(0, t))
            return x * x * (3 - 2 * x)
        }

        let fadeIn = smoothstep(progress / 0.35)
        let fadeOut = smoothstep((1.0 - progress) / 0.30)

        return min(fadeIn, fadeOut)
    }

    /// Maps 0...1 to a stoplight hue: red at 0, yellow at 0.5, green at 1,
    /// interpolated smoothly and continuously in RGB space.
    private static func stoplightColor(intensity: Double) -> Color {
        let t = min(max(intensity, 0), 1)
        if t < 0.5 {
            return Color(red: 1.0, green: t / 0.5, blue: 0.0)
        } else {
            return Color(red: 1.0 - (t - 0.5) / 0.5, green: 1.0, blue: 0.0)
        }
    }
}

#Preview {
    let currentYear = Calendar.current.component(.year, from: .now)
    return VStack(alignment: .leading, spacing: 16) {
        DrinkWindowTimelineView(bottle: Bottle(name: "Both bounds", wineType: .red, drinkWindowStartYear: currentYear + 2, drinkWindowEndYear: currentYear + 8), horizonYear: currentYear + 10)
        DrinkWindowTimelineView(bottle: Bottle(name: "Open-ended", wineType: .white, drinkWindowStartYear: currentYear + 1, drinkWindowEndYear: nil), horizonYear: currentYear + 10)
        DrinkWindowTimelineView(bottle: Bottle(name: "No start", wineType: .rose, drinkWindowStartYear: nil, drinkWindowEndYear: currentYear + 5), horizonYear: currentYear + 10)
        DrinkWindowTimelineView(bottle: Bottle(name: "Overdue", wineType: .fortified, drinkWindowStartYear: currentYear - 8, drinkWindowEndYear: currentYear - 2), horizonYear: currentYear + 10)
        DrinkWindowTimelineView(bottle: Bottle(name: "Beyond horizon", wineType: .sparkling, drinkWindowStartYear: currentYear + 15, drinkWindowEndYear: currentYear + 20), horizonYear: currentYear + 10)
    }
    .padding()
}
