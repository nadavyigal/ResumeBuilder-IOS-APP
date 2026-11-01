import AppKit
import Vision
let image = NSImage(contentsOfFile: CommandLine.arguments[1])!
let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil)!
let request = VNRecognizeTextRequest()
request.recognitionLevel = .accurate
try VNImageRequestHandler(cgImage: cg).perform([request])
for result in request.results ?? [] { if let text = result.topCandidates(1).first { print(text.string) } }
