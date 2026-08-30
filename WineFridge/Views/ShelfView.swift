//
//  ShelfView.swift
//  WineFridge
//

import SwiftUI

/// A single shelf. When it has two rows, the top row is staggered by half a
/// cell width so bottles nest between the ones below; a single-row shelf is
/// rendered flat.
struct ShelfView: View {
    let shelf: Shelf
    let shelfNumber: Int
    let bottlesBySlot: [SlotID: Bottle]
    let availableWidth: CGFloat
    let onSelectSlot: (SlotID) -> Void
    let onMoveBottle: (SlotID, SlotID) -> Void

    private let spacing: CGFloat = 18
    private let containerPadding: CGFloat = 12

    /// The cell size that makes a staggered top row (offset by half a cell)
    /// and the bottom row both fill the available width exactly.
    private var cellSize: CGFloat {
        let n = CGFloat(shelf.slotsPerRow)
        let width = max(availableWidth - containerPadding * 2, 0)
        if shelf.rowCount > 1 {
            return max((width - spacing * (n - 0.5)) / (n + 0.5), 0)
        } else {
            return max((width - spacing * (n - 1)) / n, 0)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Shelf \(shelfNumber)")
                .font(.headline)
                .foregroundStyle(.secondary)

            VStack(spacing: 10) {
                if shelf.rowCount > 1 {
                    row(rowIndex: 0)
                        .padding(.leading, (cellSize + spacing) / 2)
                    row(rowIndex: 1)
                } else {
                    row(rowIndex: 0)
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

    private func row(rowIndex: Int) -> some View {
        HStack(spacing: spacing) {
            ForEach(0..<shelf.slotsPerRow, id: \.self) { column in
                let slot = SlotID(shelfID: shelf.shelfID, row: rowIndex, column: column)
                cell(for: slot)
            }
        }
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
