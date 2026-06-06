import Foundation

#if canImport(Vision) && canImport(ImageIO)
import ImageIO
import Vision
#endif

public struct AttachmentVisionReference: Equatable, Sendable {
    public var ocrText: String?
    public var labels: [String]

    public init(ocrText: String? = nil, labels: [String] = []) {
        self.ocrText = ocrText
        self.labels = labels
    }

    public var isEmpty: Bool {
        let hasOCR = ocrText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        return !hasOCR && labels.isEmpty
    }

    public var promptPreview: String? {
        guard !isEmpty else { return nil }
        var sections: [String] = []
        if let ocrText, !ocrText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            sections.append(KairoL10n.string("chat.capture.photoVisionOCRSection", ocrText))
        }
        if !labels.isEmpty {
            sections.append(KairoL10n.string("chat.capture.photoVisionLabelsSection", labels.joined(separator: ", ")))
        }
        return sections.joined(separator: "\n")
    }
}

public enum AttachmentVisionAnalyzer {
    public static func reference(from imageData: Data) async -> AttachmentVisionReference {
        #if canImport(Vision) && canImport(ImageIO)
        return await Task.detached(priority: .userInitiated) {
            guard let source = CGImageSourceCreateWithData(imageData as CFData, nil),
                  let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
            else {
                return AttachmentVisionReference()
            }

            let textRequest = VNRecognizeTextRequest()
            textRequest.recognitionLevel = .accurate
            textRequest.usesLanguageCorrection = true

            let classifyRequest = VNClassifyImageRequest()
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            try? handler.perform([textRequest, classifyRequest])

            let ocrText = textRequest.results?
                .compactMap { $0.topCandidates(1).first?.string }
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            let labels = (classifyRequest.results ?? [])
                .prefix(5)
                .filter { $0.confidence >= 0.12 }
                .map { observation in
                    let confidence = Int((observation.confidence * 100).rounded())
                    return "\(observation.identifier) \(confidence)%"
                }

            return AttachmentVisionReference(
                ocrText: ocrText.map { String($0.prefix(2_400)) },
                labels: labels
            )
        }.value
        #else
        return AttachmentVisionReference()
        #endif
    }
}
