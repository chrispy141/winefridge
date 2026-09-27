//
//  WineLabelTextRecognizer.swift
//  WineStorage
//

import UIKit
import Vision

/// Performs on-device OCR on a photo of a wine label using the Vision framework.
///
/// This is deliberately the only part of the label-scanning pipeline that
/// touches Vision, so it can be tested independently of how the recognized
/// text is later interpreted (see `WineLabelInterpreter`).
enum WineLabelTextRecognizer {
    enum RecognitionError: Error {
        /// The provided image couldn't be converted for Vision to analyze.
        case invalidImage
    }

    /// Recognizes text in the given wine-label photo and returns it as a
    /// block of text, one line per recognized line of text on the label.
    ///
    /// All analysis happens on-device; no image data or recognized text
    /// leaves the device.
    static func recognizeText(in image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw RecognitionError.invalidImage
        }
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let observations = request.results as? [VNRecognizedTextObservation] ?? []
                let lines = observations.compactMap { $0.topCandidates(1).first?.string }
                continuation.resume(returning: lines.joined(separator: "\n"))
            }
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
