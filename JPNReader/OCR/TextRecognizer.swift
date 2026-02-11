import Cocoa
import Vision
import CoreImage
import SwiftyTesseract
import libtesseract

// Source - https://stackoverflow.com/a/78669720
// Posted by Basel
// Retrieved 2026-02-11, License - CC BY-SA 4.0

public typealias PageSegmentationMode = TessPageSegMode

public extension PageSegmentationMode {
    static let osdOnly = PSM_OSD_ONLY
    static let autoOsd = PSM_AUTO_OSD
    static let autoOnly = PSM_AUTO_ONLY
    static let auto = PSM_AUTO
    static let singleColumn = PSM_SINGLE_COLUMN
    static let singleBlockVerticalText = PSM_SINGLE_BLOCK_VERT_TEXT
    static let singleBlock = PSM_SINGLE_BLOCK
    static let singleLine = PSM_SINGLE_LINE
    static let singleWord = PSM_SINGLE_WORD
    static let circleWord = PSM_CIRCLE_WORD
    static let singleCharacter = PSM_SINGLE_CHAR
    static let sparseText = PSM_SPARSE_TEXT
    static let sparseTextOsd = PSM_SPARSE_TEXT_OSD
    static let count = PSM_COUNT
}

public extension Tesseract {
    var pageSegmentationMode: PageSegmentationMode {
        get {
            perform { tessPointer in
                TessBaseAPIGetPageSegMode(tessPointer)
            }
        }
        set {
            perform { tessPointer in
                TessBaseAPISetPageSegMode(tessPointer, newValue)
            }
        }
    }
}

struct TextRecognizer {
    static func recognizeJapanese(from image: CGImage, completion: @escaping (String) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let enhanced = preprocessImage(image) ?? image

            // Pass 1: SwiftyTesseract with jpn_vert model (vertical text)
            let verticalResult = runTesseractOCR(on: enhanced)

            // Pass 2: Vision framework (horizontal text)
            let horizontalResult = runVisionOCR(on: enhanced)

            let best = [verticalResult, horizontalResult]
                .max(by: { $0.count < $1.count }) ?? ""

            DispatchQueue.main.async { completion(best) }
        }
    }

    // MARK: - Tesseract OCR (Vertical Text)

    private static func runTesseractOCR(on image: CGImage) -> String {
        let tesseract = Tesseract(
            language: .custom("jpn_vert"),
            dataSource: Bundle.main,
            engineMode: .lstmOnly
        )

        tesseract.pageSegmentationMode = .singleBlockVerticalText

        // Convert CGImage to JPEG data for Tesseract
        let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        guard let tiffData = nsImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let jpegData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 1.0]) else {
            return ""
        }

        switch tesseract.performOCR(on: jpegData) {
        case .success(let text):
            return text.trimmingCharacters(in: .whitespacesAndNewlines)
        case .failure(let error):
            print("Tesseract OCR error: \(error)")
            return ""
        }
    }

    // MARK: - Vision OCR (Horizontal Text)

    private static func runVisionOCR(on image: CGImage) -> String {
        var recognized = ""
        let semaphore = DispatchSemaphore(value: 0)

        let request = VNRecognizeTextRequest { request, error in
            defer { semaphore.signal() }
            if let error = error {
                print("Vision OCR error: \(error.localizedDescription)")
                return
            }
            guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
            recognized = observations
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: "\n")
        }

        request.recognitionLanguages = ["ja", "en"]
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = true

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([request])
        } catch {
            print("Vision OCR failed: \(error.localizedDescription)")
            semaphore.signal()
        }
        semaphore.wait()
        return recognized
    }

    // MARK: - Image Preprocessing

    private static func preprocessImage(_ image: CGImage) -> CGImage? {
        var ciImage = CIImage(cgImage: image)

        ciImage = ciImage.transformed(by: CGAffineTransform(scaleX: 2, y: 2))

        if let filter = CIFilter(name: "CIColorControls") {
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            filter.setValue(1.5, forKey: kCIInputContrastKey)
            filter.setValue(0.0, forKey: kCIInputSaturationKey)
            filter.setValue(0.1, forKey: kCIInputBrightnessKey)
            if let output = filter.outputImage {
                ciImage = output
            }
        }

        if let filter = CIFilter(name: "CISharpenLuminance") {
            filter.setValue(ciImage, forKey: kCIInputImageKey)
            filter.setValue(1.0, forKey: kCIInputSharpnessKey)
            if let output = filter.outputImage {
                ciImage = output
            }
        }

        let context = CIContext()
        return context.createCGImage(ciImage, from: ciImage.extent)
    }
}
