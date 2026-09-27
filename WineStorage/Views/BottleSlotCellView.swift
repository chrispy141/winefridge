//
//  BottleSlotCellView.swift
//  WineStorage
//

import SwiftUI
import UIKit

struct BottleSlotCellView: View {
    let bottle: Bottle?
    var size: CGFloat = 52
    var height: CGFloat?
    /// Draws a colored border around this cell plus an arrow pointing down at
    /// it, e.g. to call out where Quick Add's Auto Assign just placed a
    /// bottle. `nil` draws neither.
    var highlightColor: Color? = nil

    /// Downsampled directly from the stored photo data rather than a full
    /// `UIImage(data:)` decode — cells are small, so decoding at full
    /// resolution just to scale down for display wastes work on every
    /// re-render of a shelf full of photographed bottles.
    private var photoImage: UIImage? {
        bottle?.photoData.flatMap { UIImage.thumbnail(from: $0, maxPixelSize: 400) }
    }

    var body: some View {
        // Read once — `photoImage` decodes the photo, and this view reads it
        // several times below.
        let photoImage = photoImage
        ZStack {
            if let photoImage {
                Image(uiImage: photoImage)
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(bottle?.wineType.color.gradient ?? Color(.tertiarySystemFill).gradient)
            }
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(photoImage != nil ? (bottle?.wineType.color ?? .clear) : .black.opacity(0.15), lineWidth: photoImage != nil ? 2 : 1)

            if let highlightColor {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(highlightColor, lineWidth: 3)
            }

            if let bottle {
                let vintageText = Text(bottle.vintageDisplayText ?? "")
                if photoImage != nil {
                    VStack {
                        Spacer()
                        vintageText
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .background(.black.opacity(0.5), in: Capsule())
                            .padding(.bottom, 3)
                    }
                } else {
                    vintageText
                        .font(.caption2.bold())
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .padding(4)
                }
            } else {
                Image(systemName: "plus")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: height ?? size)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(alignment: .top) {
            if let highlightColor {
                // A colored border on the cell itself is easy to miss next to
                // the wine-type-colored border every cell already has, so
                // point an arrow down at it from just above instead.
                Image(systemName: "arrowtriangle.down.fill")
                    .font(.system(size: max(size * 0.4, 18)))
                    .foregroundStyle(highlightColor)
                    .offset(y: -max(size * 0.4, 18))
                    .accessibilityHidden(true)
            }
        }
        .accessibilityLabel(bottle?.name ?? "Empty slot")
    }
}
