//
//  BottleCutoutService.swift
//  WineStorage
//

import UIKit
import Vision
import CoreImage

/// Produces a transparent-background cutout of the bottle in a photo, using
/// Vision's on-device foreground-subject segmentation — so storage-box
/// slots can show just the bottle's silhouette instead of its full photo
/// background. All processing happens on-device; no image data leaves the
/// device.
enum BottleCutoutService {
    enum CutoutError: Error {
        case invalidImage
        case noSubjectFound
    }

    /// Returns PNG data containing just the most prominent subject Vision
    /// finds in `image` (presumed to be the bottle), cropped to that
    /// subject's extent with everything else transparent.
    static func generateCutout(from image: UIImage) async throws -> Data {
        guard let cgImage = image.cgImage else {
            throw CutoutError.invalidImage
        }
        let orientation = CGImagePropertyOrientation(uiImageOrientation: image.imageOrientation)

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNGenerateForegroundInstanceMaskRequest()
            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
            do {
                try handler.perform([request])
                guard let result = request.results?.first, !result.allInstances.isEmpty else {
                    continuation.resume(throwing: CutoutError.noSubjectFound)
                    return
                }
                let maskedPixelBuffer = try result.generateMaskedImage(
                    ofInstances: result.allInstances,
                    from: handler,
                    croppedToInstancesExtent: true
                )
                let ciImage = CIImage(cvPixelBuffer: maskedPixelBuffer)
                guard let outputCGImage = CIContext().createCGImage(ciImage, from: ciImage.extent) else {
                    continuation.resume(throwing: CutoutError.noSubjectFound)
                    return
                }
                let cutoutImage = UIImage(cgImage: outputCGImage).resized(maxDimension: 1000)
                guard let pngData = cutoutImage.pngData() else {
                    continuation.resume(throwing: CutoutError.noSubjectFound)
                    return
                }
                continuation.resume(returning: pngData)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}

private extension CGImagePropertyOrientation {
    /// `CGImage` has no orientation of its own, so Vision needs it supplied
    /// separately — this maps the orientation metadata already decoded onto
    /// `UIImage` into Vision's equivalent representation.
    init(uiImageOrientation: UIImage.Orientation) {
        switch uiImageOrientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
