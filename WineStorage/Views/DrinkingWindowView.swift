//
//  DrinkingWindowView.swift
//  WineStorage
//

import SwiftUI
import SwiftData

/// A timeline of drinking recommendations built from every bottle's
/// drinking window (see `Bottle.drinkWindowStartYear`/`drinkWindowEndYear`).
/// Bottles are grouped into "Overdue", "Drink Now", or a future year — tapping
/// a bottle's thumbnail opens the same detail sheet used from the Inventory
/// tab.
struct DrinkingWindowView: View {
    @Query(sort: \Bottle.name) private var bottles: [Bottle]
    @State private var selectedBottle: Bottle?

    private var currentYear: Int {
        Calendar.current.component(.year, from: .now)
    }

    /// Where a bottle belongs on the timeline. Ordered as the cases are
    /// declared: overdue first, then ready now, then future years in
    /// ascending order (see `sections`).
    private enum Bucket: Hashable {
        case overdue
        case now
        case future(Int)
    }

    private struct Section: Identifiable {
        let bucket: Bucket
        let bottles: [Bottle]
        var id: Bucket { bucket }
    }

    /// A bottle with only an end year is treated as ready to drink any time
    /// up to that deadline (so it lands in `.now` until the deadline passes),
    /// while a bottle with only a start year isn't ready until that year
    /// arrives. A bottle with neither year set has no window to recommend.
    private func bucket(for bottle: Bottle) -> Bucket? {
        let start = bottle.drinkWindowStartYear
        let end = bottle.drinkWindowEndYear
        guard start != nil || end != nil else { return nil }
        if let end, end < currentYear {
            return .overdue
        }
        if let start, start > currentYear {
            return .future(start)
        }
        return .now
    }

    private var sections: [Section] {
        let grouped = Dictionary(grouping: bottles.compactMap { bottle in bucket(for: bottle).map { (bottle, $0) } }, by: { $0.1 })
            .mapValues { pairs in pairs.map(\.0).sorted { $0.name < $1.name } }
        var result: [Section] = []
        if let overdue = grouped[.overdue] {
            result.append(Section(bucket: .overdue, bottles: overdue))
        }
        if let now = grouped[.now] {
            result.append(Section(bucket: .now, bottles: now))
        }
        let futureYears = grouped.keys.compactMap { bucket -> Int? in
            if case .future(let year) = bucket { return year }
            return nil
        }.sorted()
        for year in futureYears {
            result.append(Section(bucket: .future(year), bottles: grouped[.future(year)] ?? []))
        }
        return result
    }

    var body: some View {
        List {
            ForEach(sections) { section in
                SwiftUI.Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 16) {
                            ForEach(section.bottles) { bottle in
                                Button {
                                    selectedBottle = bottle
                                } label: {
                                    VStack(spacing: 4) {
                                        BottleSlotCellView(bottle: bottle, size: 48)
                                        Text(bottle.name)
                                            .font(.caption2)
                                            .lineLimit(2)
                                            .multilineTextAlignment(.center)
                                        if let window = bottle.drinkWindowDisplayText {
                                            Text(window)
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .frame(width: 64)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    header(for: section.bucket)
                }
            }
        }
        .overlay {
            if sections.isEmpty {
                ContentUnavailableView(
                    "No Drinking Windows Set",
                    systemImage: "hourglass",
                    description: Text("Add a drinking window to a bottle to see drinking recommendations here.")
                )
            }
        }
        .navigationTitle("Drinking Window")
        .sheet(item: $selectedBottle) { bottle in
            BottleDetailView(bottle: bottle)
        }
    }

    private func header(for bucket: Bucket) -> some View {
        let (title, color): (String, Color) = {
            switch bucket {
            case .overdue: return ("Overdue", .red)
            case .now: return ("Drink Now", .green)
            case .future(let year): return (String(year), .secondary)
            }
        }()
        return HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(title)
        }
    }
}

#Preview {
    NavigationStack {
        DrinkingWindowView()
    }
    .modelContainer(for: [Storage.self, Bottle.self, Shelf.self], inMemory: true)
}
