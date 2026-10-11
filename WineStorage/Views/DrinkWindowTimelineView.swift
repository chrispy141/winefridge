//
//  DrinkWindowTimelineView.swift
//  WineStorage
//

import SwiftUI

/// A compact horizontal timeline for a bottle's drinking window, shown inline
/// in the inventory list. Every bottle shares the same timeline domain — the
/// left edge is always today, and the right edge is `horizonYear` (chosen
/// once, above the whole list), so bars are directly comparable. Color shows
/// where the wine sits in its aging lifecycle (see `WineMaturity`/
/// `WineMaturityStage` and `DrinkWindowLegendView` for the on-screen key);
/// opacity separately shows how intensely that stage reads — low at the
/// edges, full at peak — independent of which color is showing.
struct DrinkWindowTimelineView: View {
    let bottle: Bottle
    let horizonYear: Int

    private static let height: CGFloat = 6
    /// Number of gradient stops sampled across the visible domain to
    /// approximate the smoothstep curve from `WineMaturity`.
    private static let sampleCount = 24
    /// The floor opacity at the ramp edges (and for an overdue bottle's
    /// solid bar, which this formula also naturally produces — see
    /// `gradientStops`) — also used by `DrinkWindowLegendView` so swatches
    /// for stages only ever seen at this floor match the bar exactly.
    static let floorOpacity: Double = 0.92

    private var currentYear: Int {
        Calendar.current.component(.year, from: .now)
    }

    /// The bottle's maturity stage as of today — used for the bar's
    /// accessibility label, since the gradient itself can't be read aloud.
    private var currentStage: WineMaturityStage? {
        WineMaturity.stage(start: bottle.drinkWindowStartYear, end: bottle.drinkWindowEndYear, asOf: currentYear)
    }

    var body: some View {
        if let stops = gradientStops {
            Capsule()
                .fill(LinearGradient(stops: stops, startPoint: .leading, endPoint: .trailing))
                .frame(height: Self.height)
                .accessibilityLabel(currentStage?.accessibilityDescription ?? "")
        }
    }

    /// Builds the maturity gradient for the bar over the fixed
    /// `[today, horizonYear]` domain by sampling `WineMaturity` at evenly
    /// spaced years, or `nil` when there's no window to show. A missing
    /// start is treated as "ready as of today"; a missing end has no real
    /// fade-out point, so `holdAtPeak` keeps the ramp from ever reading as
    /// declining once it reaches peak. A bottle whose window closed before
    /// today naturally renders as a solid `.pastPeak` bar at the floor
    /// opacity, since every sampled year across the visible domain falls
    /// after its ramp-out completes — no separate "overdue" case needed.
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

        return (0...Self.sampleCount).map { index in
            let location = Double(index) / Double(Self.sampleCount)
            let year = domainStart + location * span
            let phase = WineMaturity.phase(year: year, startYear: startYear, endYear: endYear, holdAtPeak: holdAtPeak)
            let intensity = WineMaturity.intensity(fadeIn: phase.fadeIn, fadeOut: phase.fadeOut)
            let opacity = Self.floorOpacity + (1 - Self.floorOpacity) * intensity
            let color = WineMaturity.color(fadeIn: phase.fadeIn, fadeOut: phase.fadeOut)
            return Gradient.Stop(color: color.opacity(opacity), location: location)
        }
    }
}

/// The on-screen key for `DrinkWindowTimelineView`'s maturity colors.
/// Wraps into two rows of two so it still fits beside the Outlook picker.
struct DrinkWindowLegendView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 10) {
                item(.developing)
                item(.approachingPeak)
            }
            HStack(spacing: 10) {
                item(.atPeak)
                item(.pastPeak)
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }

    private func item(_ stage: WineMaturityStage) -> some View {
        // `.developing` and `.pastPeak` are only ever seen in the bars at
        // the intensity floor, so they're flattened to match exactly (see
        // `WineMaturity.flattened`); `.approachingPeak`/`.atPeak` are shown
        // at their full, undiminished color.
        let color: Color = switch stage {
        case .developing, .pastPeak:
            WineMaturity.flattened(stage.color, opacity: DrinkWindowTimelineView.floorOpacity)
        case .approachingPeak, .atPeak:
            stage.color
        }
        return HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(stage.label)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
    }
}

/// A shared year axis drawn above a list of `DrinkWindowTimelineView` bars,
/// so every bar's `[startYear, endYear]` domain has on-screen context without
/// repeating labels on every row. Draws a labeled tick at every 5-year
/// increment between the two endpoints, which are always ticks themselves.
/// Relies on every tick year being the same digit count so evenly spacing
/// the ticks with `Spacer()` lines them up with the years they're under.
struct DrinkWindowAxisView: View {
    let startYear: Int
    let endYear: Int

    private var tickYears: [Int] {
        guard endYear > startYear else { return [startYear] }
        return Array(stride(from: startYear, through: endYear, by: 5))
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(tickYears.enumerated()), id: \.element) { index, year in
                if index > 0 {
                    Spacer()
                }
                VStack(spacing: 2) {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.6))
                        .frame(width: 1, height: 8)
                    Text(String(year))
                }
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
    }
}

#Preview {
    let currentYear = Calendar.current.component(.year, from: .now)
    return VStack(alignment: .leading, spacing: 16) {
        DrinkWindowLegendView()
        DrinkWindowAxisView(startYear: currentYear, endYear: currentYear + 10)
        DrinkWindowTimelineView(bottle: Bottle(name: "Both bounds", wineType: .red, drinkWindowStartYear: currentYear + 2, drinkWindowEndYear: currentYear + 8), horizonYear: currentYear + 10)
        DrinkWindowTimelineView(bottle: Bottle(name: "Open-ended", wineType: .white, drinkWindowStartYear: currentYear + 1, drinkWindowEndYear: nil), horizonYear: currentYear + 10)
        DrinkWindowTimelineView(bottle: Bottle(name: "No start", wineType: .rose, drinkWindowStartYear: nil, drinkWindowEndYear: currentYear + 5), horizonYear: currentYear + 10)
        DrinkWindowTimelineView(bottle: Bottle(name: "Overdue", wineType: .fortified, drinkWindowStartYear: currentYear - 8, drinkWindowEndYear: currentYear - 2), horizonYear: currentYear + 10)
        DrinkWindowTimelineView(bottle: Bottle(name: "Beyond horizon", wineType: .sparkling, drinkWindowStartYear: currentYear + 15, drinkWindowEndYear: currentYear + 20), horizonYear: currentYear + 10)
    }
    .padding()
}
