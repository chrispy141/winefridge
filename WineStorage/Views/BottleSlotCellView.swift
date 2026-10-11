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
    /// Whether a cell showing a photo draws its border colored by wine
    /// style (red, white, etc.) rather than a plain neutral one — see
    /// `Storage.showsWineTypeBorders`.
    var showsWineTypeBorder: Bool = true

    /// A transparent-background cutout of just the bottle (see
    /// `BottleCutoutService`), downsampled directly from the stored data
    /// rather than a full `UIImage(data:)` decode — cells are small, so
    /// decoding at full resolution just to scale down for display wastes
    /// work on every re-render of a shelf full of photographed bottles.
    /// Preferred over `fullPhotoImage` whenever it's available, since it
    /// shows just the bottle rather than its photographed surroundings.
    private var cutoutImage: UIImage? {
        bottle?.cutoutPhotoData.flatMap { UIImage.thumbnail(from: $0, maxPixelSize: 400) }
    }

    /// The bottle's full, uncropped photo, downsampled the same way as
    /// `cutoutImage`. Shown only when no cutout is available — e.g. the
    /// cutout hasn't finished generating yet, or Vision couldn't isolate a
    /// subject in the photo.
    private var fullPhotoImage: UIImage? {
        bottle?.photoData.flatMap { UIImage.thumbnail(from: $0, maxPixelSize: 400) }
    }

    var body: some View {
        // Read once — these decode the stored photo data, and this view
        // reads the results several times below.
        let cutoutImage = cutoutImage
        let fullPhotoImage = cutoutImage == nil ? fullPhotoImage : nil
        let hasImage = cutoutImage != nil || fullPhotoImage != nil
        let showsColoredBorder = hasImage && showsWineTypeBorder
        ZStack {
            // A cutout's background is deliberately left blank/see-through
            // — no fill behind it — so only the bottle itself shows, inside
            // the cell's border.
            if let cutoutImage {
                Image(uiImage: cutoutImage)
                    .resizable()
                    .scaledToFit()
                    .padding(size * 0.1)
            } else if let fullPhotoImage {
                Image(uiImage: fullPhotoImage)
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(bottle?.wineType.color.gradient ?? Color(.tertiarySystemFill).gradient)
            }
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(showsColoredBorder ? (bottle?.wineType.color ?? .clear) : .black.opacity(0.15), lineWidth: showsColoredBorder ? 2 : 1)

            if let highlightColor {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(highlightColor, lineWidth: 3)
            }

            if let bottle {
                let vintageText = Text(bottle.vintageDisplayText ?? "")
                if hasImage {
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
