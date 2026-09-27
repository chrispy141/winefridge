//
//  WineLabelScanner.swift
//  WineStorage
//

import UIKit
import FoundationModels

/// Coordinates on-device wine-label recognition for the Add Bottle workflow:
/// Vision OCR (`WineLabelTextRecognizer`) followed by Foundation Models
/// interpretation (`WineLabelInterpreter`). Views should talk to this type
/// rather than the two stages directly.
///
/// Everything runs on-device — no image data or recognized text is ever
/// sent off-device.
enum WineLabelScanner {
    enum Outcome {
        /// The label was read and interpreted into structured wine information.
        case extracted(WineLabelExtraction)
        /// Text was recognized, but structured interpretation isn't available
        /// on this device right now. `reason` is safe to show to someone
        /// using the app.
        case interpreterUnavailable(reason: String)
    }

    enum ScanError: Error {
        /// Vision didn't find any recognizable text in the photo.
        case noTextFound
    }

    static func scan(image: UIImage) async throws -> Outcome {
        let ocrText = try await WineLabelTextRecognizer.recognizeText(in: image)
        guard !ocrText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ScanError.noTextFound
        }

        if #available(iOS 26.0, *) {
            switch WineLabelInterpreter.availability() {
            case .available:
                let extraction = try await WineLabelInterpreter().interpret(ocrText: ocrText)
                return .extracted(extraction)
            case .unavailable(let reason):
                return .interpreterUnavailable(reason: WineLabelInterpreter.describe(reason))
            }
        } else {
            return .interpreterUnavailable(
                reason: "Intelligent label interpretation requires a supported Apple Intelligence device."
            )
        }
    }
}
