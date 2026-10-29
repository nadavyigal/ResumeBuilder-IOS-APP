// Encodes a folder of PNG frames into an App Store app preview:
// H.264 High 4.0, 30 fps, ~11 Mbps, plus a silent stereo AAC 256 kbps / 48 kHz track.
// usage: swift encode.swift <framesDir> <out.mov> <width> <height>
import AVFoundation
import AppKit

let a = CommandLine.arguments
let dir = URL(fileURLWithPath: a[1]), out = URL(fileURLWithPath: a[2])
let W = Int(a[3])!, H = Int(a[4])!, fps: Int32 = 30
try? FileManager.default.removeItem(at: out)
let files = try FileManager.default.contentsOfDirectory(atPath: dir.path).filter { $0.hasSuffix(".png") }.sorted()

let writer = try AVAssetWriter(outputURL: out, fileType: .mov)
let video = AVAssetWriterInput(mediaType: .video, outputSettings: [
  AVVideoCodecKey: AVVideoCodecType.h264,
  AVVideoWidthKey: W, AVVideoHeightKey: H,
  AVVideoCompressionPropertiesKey: [
    AVVideoAverageBitRateKey: 11_000_000,
    AVVideoProfileLevelKey: AVVideoProfileLevelH264High40,
    AVVideoExpectedSourceFrameRateKey: fps,
    AVVideoMaxKeyFrameIntervalKey: 30,
  ],
])
video.expectsMediaDataInRealTime = false
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: video, sourcePixelBufferAttributes: [
  kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
  kCVPixelBufferWidthKey as String: W, kCVPixelBufferHeightKey as String: H,
])
let rate = 48_000.0
let audio = AVAssetWriterInput(mediaType: .audio, outputSettings: [
  AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: rate,
  AVNumberOfChannelsKey: 2, AVEncoderBitRateKey: 256_000,
])
audio.expectsMediaDataInRealTime = false
writer.add(video); writer.add(audio)
writer.startWriting(); writer.startSession(atSourceTime: .zero)
func check() {
  if writer.status == .failed { print("writer failed:", writer.error as Any); exit(1) }
}

// Silent stereo PCM, encoded to AAC by the writer. Each track is fed on its own queue whenever the
// writer asks for more, which is Apple's pattern for interleaving; feeding them in lockstep deadlocks.
let total = Int(Double(files.count) / Double(fps) * rate)
var asbd = AudioStreamBasicDescription(mSampleRate: rate, mFormatID: kAudioFormatLinearPCM,
  mFormatFlags: kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked, mBytesPerPacket: 4,
  mFramesPerPacket: 1, mBytesPerFrame: 4, mChannelsPerFrame: 2, mBitsPerChannel: 16, mReserved: 0)
var fmt: CMAudioFormatDescription?
CMAudioFormatDescriptionCreate(allocator: nil, asbd: &asbd, layoutSize: 0, layout: nil, magicCookieSize: 0,
  magicCookie: nil, extensions: nil, formatDescriptionOut: &fmt)

let group = DispatchGroup()
group.enter(); group.enter()

var frame = 0
video.requestMediaDataWhenReady(on: DispatchQueue(label: "video")) {
  while video.isReadyForMoreMediaData {
    if frame >= files.count { video.markAsFinished(); group.leave(); return }
    autoreleasepool {
      let img = NSImage(contentsOf: dir.appendingPathComponent(files[frame]))!
      let cg = img.cgImage(forProposedRect: nil, context: nil, hints: nil)!
      var pb: CVPixelBuffer?
      CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &pb)
      let buf = pb!
      CVPixelBufferLockBaseAddress(buf, [])
      let ctx = CGContext(data: CVPixelBufferGetBaseAddress(buf), width: W, height: H, bitsPerComponent: 8,
                          bytesPerRow: CVPixelBufferGetBytesPerRow(buf), space: CGColorSpace(name: CGColorSpace.sRGB)!,
                          bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)!
      ctx.draw(cg, in: CGRect(x: 0, y: 0, width: W, height: H))
      CVPixelBufferUnlockBaseAddress(buf, [])
      adaptor.append(buf, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: fps))
    }
    frame += 1
  }
  check()
}

var done = 0
audio.requestMediaDataWhenReady(on: DispatchQueue(label: "audio")) {
  while audio.isReadyForMoreMediaData {
    if done >= total { audio.markAsFinished(); group.leave(); return }
    let n = min(4800, total - done)
    var block: CMBlockBuffer?
    CMBlockBufferCreateWithMemoryBlock(allocator: nil, memoryBlock: nil, blockLength: n * 4, blockAllocator: nil,
      customBlockSource: nil, offsetToData: 0, dataLength: n * 4, flags: kCMBlockBufferAssureMemoryNowFlag, blockBufferOut: &block)
    CMBlockBufferFillDataBytes(with: 0, blockBuffer: block!, offsetIntoDestination: 0, dataLength: n * 4)
    var sb: CMSampleBuffer?
    CMAudioSampleBufferCreateReadyWithPacketDescriptions(allocator: nil, dataBuffer: block!, formatDescription: fmt!,
      sampleCount: n, presentationTimeStamp: CMTime(value: CMTimeValue(done), timescale: CMTimeScale(rate)),
      packetDescriptions: nil, sampleBufferOut: &sb)
    audio.append(sb!)
    done += n
  }
  check()
}

group.wait()
let sem = DispatchSemaphore(value: 0)
writer.endSession(atSourceTime: CMTime(value: CMTimeValue(files.count), timescale: fps))
writer.finishWriting { sem.signal() }
sem.wait()
print(writer.status == .completed ? "ok \(files.count) frames" : "failed \(String(describing: writer.error))")
