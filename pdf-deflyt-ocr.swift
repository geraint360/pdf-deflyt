// pdf-deflyt-ocr: report the text macOS Vision can read in each image.
//
// Used by pdf-deflyt's photo cap to decide whether an image carries text (screenshots,
// charts, maps, scanned pages) and must keep its resolution, and to check that a
// downsampled image is still as legible as the original.
//
// Usage: pdf-deflyt-ocr IMAGE...
// Output: one JSON object per image, one per line: {"file": "...", "text": ["...", ...]}
// Exit status: 0 on success, 1 if any image could not be read.

import Foundation
import Vision
import ImageIO

func recognise(_ path: String) -> [String]? {
    let url = URL(fileURLWithPath: path)
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        return nil
    }
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    // Report what is legible in the pixels, not what a dictionary would guess
    request.usesLanguageCorrection = false
    do {
        try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
    } catch {
        return nil
    }
    return (request.results ?? []).compactMap { observation in
        guard let best = observation.topCandidates(1).first, best.confidence >= 0.5 else { return nil }
        return best.string
    }
}

var failed = false
for path in CommandLine.arguments.dropFirst() {
    guard let text = recognise(path) else {
        FileHandle.standardError.write("pdf-deflyt-ocr: cannot read \(path)\n".data(using: .utf8)!)
        failed = true
        continue
    }
    let line: [String: Any] = ["file": path, "text": text]
    let data = try! JSONSerialization.data(withJSONObject: line, options: [.sortedKeys])
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write("\n".data(using: .utf8)!)
}
exit(failed ? 1 : 0)
