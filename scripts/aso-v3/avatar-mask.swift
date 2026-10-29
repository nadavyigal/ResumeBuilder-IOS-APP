import Foundation
import Vision
import CoreImage
// usage: mask.swift <in.png> <out-mask.png>  — full-frame soft mask of every subject Vision finds
let a = CommandLine.arguments
let ci = CIImage(contentsOf: URL(fileURLWithPath: a[1]))!
let handler = VNImageRequestHandler(ciImage: ci)
let req = VNGenerateForegroundInstanceMaskRequest()
try handler.perform([req])
guard let obs = req.results?.first else { print("none"); exit(0) }
let m = try obs.generateScaledMaskForImage(forInstances: obs.allInstances, from: handler)
let out = CIImage(cvPixelBuffer: m)
try CIContext().writePNGRepresentation(of: out, to: URL(fileURLWithPath: a[2]), format: .L8, colorSpace: CGColorSpaceCreateDeviceGray())
print("ok", out.extent)
