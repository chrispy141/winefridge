//
//  UIImage+Resized.swift
//  WineStorage
//

import UIKit
import ImageIO

extension UIImage {
    /// Downscales the image so its longest side is at most `maxDimension`,
    /// keeping stored bottle photos small. Returns `self` unchanged if already smaller.
    func resized(maxDimension: CGFloat) -> UIImage {
        let scale = min(1, maxDimension / max(size.width, size.height))
        guard scale < 1 else { return self }
        let newSize = CGSize(width: size.width * scale, height: size.height * scale)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }

    /// Decodes `data` straight into an image no larger than `maxPixelSize` on
    /// its longest side, using ImageIO's thumbnail generation. Unlike
    /// `UIImage(data:)`, this never decodes the full-resolution image, which
    /// matters for grids that show many small bottle-photo thumbnails at
    /// once — decoding each one at full size (then letting SwiftUI scale it
    /// down for display) wastes CPU/memory on every scroll and re-render.
    static func thumbnail(from data: Data, maxPixelSize: CGFloat) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceCreateThumbnailWithTransform: true
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
