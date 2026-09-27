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
    /// Highlights this cell as the slot currently pending confirmation, e.g.
    /// while Quick Add's "Choose Location" step is waiting on a placement to
    /// be confirmed.
    var isSelected: Bool = false

    private var photoImage: UIImage? {
        bottle?.photoData.flatMap(UIImage.init(data:))
    }

    var body: some View {
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

            if isSelected {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.accentColor, lineWidth: 3)
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
        .accessibilityLabel(bottle?.name ?? "Empty slot")
    }
}
