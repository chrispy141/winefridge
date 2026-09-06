//
//  ShelfView.swift
//  WineFridge
//

import SwiftUI

/// A single shelf. Rows can hold different numbers of bottles — each row is
/// centered relative to the widest row, so e.g. a shelf with rows of 6, 5,
/// then 4 bottles tapers into a pyramid where bottles nest between the ones
/// in the row below. Separately, if `shelf.isOffsetRows` is on, every row but
/// the bottommost is nudged right by half a bottle width so same-width rows
/// nest in a classic staggered wine-rack pattern.
struct ShelfView: View {
    let shelf: Shelf
    let shelfNumber: Int
    let bottlesBySlot: [SlotID: Bottle]
    let availableWidth: CGFloat
    let onSelectSlot: (SlotID) -> Void
    let onMoveBottle: (SlotID, SlotID) -> Void

    private let spacing: CGFloat = 18
    private let containerPadding: CGFloat = 12

    private var maxSlotsPerRow: Int { shelf.rowSlotCounts.max() ?? 0 }

    /// Whether rows nest via a half-width offset. With only one row, there's
    /// no row below to offset from, so it has no effect either way.
    private var isOffsetting: Bool { shelf.isOffsetRows && shelf.rowCount > 1 }

    /// The cell size that makes the widest row fill the available width
    /// exactly, reserving an extra half cell of room when rows are offset so
    /// the nested rows don't overflow.
    private var cellSize: CGFloat {
        let n = CGFloat(maxSlotsPerRow)
        guard n > 0 else { return 0 }
        let width = max(availableWidth - containerPadding * 2, 0)
        if isOffsetting {
            return max((width - spacing * (n - 0.5)) / (n + 0.5), 0)
        }
        return max((width - spacing * (n - 1)) / n, 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Shelf \(shelfNumber)")
                .font(.headline)
                .foregroundStyle(.secondary)

            VStack(spacing: 10) {
                ForEach(Array(shelf.rowSlotCounts.enumerated()), id: \.offset) { rowIndex, count in
                    row(rowIndex: rowIndex, count: count)
                }
            }
            .padding(containerPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(.brown.opacity(0.15))
            )
        }
    }

    private func row(rowIndex: Int, count: Int) -> some View {
        HStack(spacing: spacing) {
            ForEach(0..<count, id: \.self) { column in
                let slot = SlotID(shelfID: shelf.shelfID, row: rowIndex, column: column)
                cell(for: slot)
            }
        }
        .padding(.leading, leadingPadding(rowIndex: rowIndex, count: count))
    }

    /// Centers a narrower row within the widest row, then — if offsetting is
    /// on — nudges every row but the bottommost by half a cell so its
    /// bottles nest between the pair below.
    private func leadingPadding(rowIndex: Int, count: Int) -> CGFloat {
        let centering = CGFloat(maxSlotsPerRow - count) * (cellSize + spacing) / 2
        let isBottomRow = rowIndex == shelf.rowSlotCounts.count - 1
        let stagger = (isOffsetting && !isBottomRow) ? (cellSize + spacing) / 2 : 0
        return centering + stagger
    }

    @ViewBuilder
    private func cell(for slot: SlotID) -> some View {
        let base = BottleSlotCellView(bottle: bottlesBySlot[slot], size: cellSize, height: cellSize * 2)
            .onTapGesture { onSelectSlot(slot) }
            .dropDestination(for: SlotID.self) { sourceSlots, _ in
                guard let sourceSlot = sourceSlots.first else { return false }
                onMoveBottle(sourceSlot, slot)
                return true
            }

        if bottlesBySlot[slot] != nil {
            base.draggable(slot)
        } else {
            base
        }
    }
}
