// Prints an app preview's tracks, and writes stills at the given seconds, to check it against Apple's spec.
// usage: probe <movie> <outDir> [seconds...]
import AVFoundation
import AppKit
let args = CommandLine.arguments
let asset = AVURLAsset(url: URL(fileURLWithPath: args[1]))
let sem = DispatchSemaphore(value: 0)
Task {
  let d = try await asset.load(.duration)
  print("duration", CMTimeGetSeconds(d))
  for t in try await asset.load(.tracks) {
    let size = try await t.load(.naturalSize), fps = try await t.load(.nominalFrameRate), rate = try await t.load(.estimatedDataRate)
    let enabled = try await t.load(.isEnabled)
    for f in try await t.load(.formatDescriptions) {
      let sub = CMFormatDescriptionGetMediaSubType(f)
      let code = String(bytes: [UInt8(sub >> 24 & 255), UInt8(sub >> 16 & 255), UInt8(sub >> 8 & 255), UInt8(sub & 255)], encoding: .ascii) ?? "?"
      var extra = ""
      if let a = CMAudioFormatDescriptionGetStreamBasicDescription(f)?.pointee { extra = "channels \(a.mChannelsPerFrame) rate \(a.mSampleRate)" }
      print(t.mediaType.rawValue, code, "\(Int(size.width))x\(Int(size.height))", "fps", fps, "kbps", Int(rate / 1000), extra, "enabled", enabled)
    }
  }
  let gen = AVAssetImageGenerator(asset: asset)
  gen.requestedTimeToleranceBefore = .zero; gen.requestedTimeToleranceAfter = .zero
  for s in args.dropFirst(3) {
    let (img, _) = try await gen.image(at: CMTime(seconds: Double(s)!, preferredTimescale: 600))
    let rep = NSBitmapImageRep(cgImage: img)
    try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(args[2])/v\(s).png"))
  }
  sem.signal()
}
sem.wait()
