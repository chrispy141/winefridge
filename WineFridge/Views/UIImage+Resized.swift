//
//  UIImage+Resized.swift
//  WineFridge
//

import UIKit

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
}
