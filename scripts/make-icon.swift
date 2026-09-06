// scripts/make-icon.swift — draw the app icon.
//
// The icon is generated rather than drawn by hand, so it can be adjusted by
// changing numbers here and re-running, and so nothing in the repository is a
// binary nobody can edit.
//
// Usage: swift scripts/make-icon.swift <output.png>

import CoreGraphics
import CoreImage
import Foundation
import ImageIO
import UniformTypeIdentifiers

let side = 1024

/// A small seeded generator, so the same icon comes out every run.
struct Random {
  var state: UInt64
  mutating func next() -> Double {
    state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
    return Double(state >> 11) / Double(UInt64(1) << 53)
  }

  mutating func next(_ low: Double, _ high: Double) -> Double {
    low + next() * (high - low)
  }
}

/// Warm to cool, the way a bloom looks when the crema breaks up.
let palette: [(Double, Double, Double)] = [
  (0.99, 0.45, 0.10),
  (0.96, 0.20, 0.42),
  (0.72, 0.18, 0.78),
  (0.36, 0.24, 0.90),
  (0.10, 0.70, 0.84),
  (0.99, 0.78, 0.22),
]

let space = CGColorSpaceCreateDeviceRGB()
guard let context = CGContext(
  data: nil,
  width: side,
  height: side,
  bitsPerComponent: 8,
  bytesPerRow: 0,
  space: space,
  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
  FileHandle.standardError.write(Data("cannot make a bitmap context\n".utf8))
  exit(1)
}

// A dark ground, so every blob laid over it reads as light rather than paint.
context.setFillColor(CGColor(red: 0.06, green: 0.03, blue: 0.12, alpha: 1))
context.fill(CGRect(x: 0, y: 0, width: side, height: side))

// Blobs on a widening spiral. Screen blending means overlaps brighten and
// shift hue instead of covering, which is what makes the transitions.
context.setBlendMode(.screen)
var random = Random(state: 20_260_906)
let centre = Double(side) / 2
let turns = 2.6
let count = 22

for index in 0 ..< count {
  let progress = Double(index) / Double(count - 1)
  let angle = progress * turns * 2 * Double.pi
  let arm = (0.16 + progress * 0.30) * Double(side)
  let jitter = random.next(0.86, 1.14)
  let x = centre + cos(angle) * arm * jitter
  let y = centre + sin(angle) * arm * jitter
  let radius = Double(side) * random.next(0.10, 0.26)

  let (red, green, blue) = palette[index % palette.count]
  let inner = CGColor(red: red, green: green, blue: blue, alpha: random.next(0.50, 0.78))
  let outer = CGColor(red: red, green: green, blue: blue, alpha: 0)
  guard let gradient = CGGradient(
    colorsSpace: space,
    colors: [inner, outer] as CFArray,
    locations: [0, 1]
  ) else { continue }

  context.drawRadialGradient(
    gradient,
    startCenter: CGPoint(x: x, y: y),
    startRadius: 0,
    endCenter: CGPoint(x: x, y: y),
    endRadius: radius,
    options: []
  )
}

guard let flat = context.makeImage() else { exit(1) }

// Twirls, not one: a single centred twirl reads as a target. Three off-centre
// ones at different radii drag the colour boundaries into each other.
var image = CIImage(cgImage: flat).clampedToExtent()
let twirls: [(Double, Double, Double, Double)] = [
  (0.50, 0.50, 0.70, 4.4),
  (0.30, 0.66, 0.36, -2.8),
  (0.72, 0.34, 0.32, 2.6),
  (0.44, 0.28, 0.22, -1.8),
]

for (fx, fy, fr, angle) in twirls {
  let filter = CIFilter(name: "CITwirlDistortion")!
  filter.setValue(image, forKey: kCIInputImageKey)
  filter.setValue(
    CIVector(x: Double(side) * fx, y: Double(side) * fy),
    forKey: kCIInputCenterKey
  )
  filter.setValue(Double(side) * fr, forKey: kCIInputRadiusKey)
  filter.setValue(angle, forKey: kCIInputAngleKey)
  image = filter.outputImage!.clampedToExtent()
}

// Lift the saturation a little; the twirl averages neighbouring colour and
// leaves the result flatter than it went in.
let vibrance = CIFilter(name: "CIVibrance")!
vibrance.setValue(image, forKey: kCIInputImageKey)
vibrance.setValue(0.45, forKey: "inputAmount")
image = vibrance.outputImage!

let frame = CGRect(x: 0, y: 0, width: side, height: side)
let ciContext = CIContext(options: [.workingColorSpace: space])
guard let output = ciContext.createCGImage(image, from: frame) else { exit(1) }

let path = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon.png"
let url = URL(fileURLWithPath: path)
guard let destination = CGImageDestinationCreateWithURL(
  url as CFURL,
  UTType.png.identifier as CFString,
  1,
  nil
) else { exit(1) }
CGImageDestinationAddImage(destination, output, nil)
guard CGImageDestinationFinalize(destination) else { exit(1) }
print("wrote \(path)")
