// scripts/make-icon.swift — draw the app icon, and the sheets it was chosen from.
//
// The icon is generated rather than drawn by hand, so it can be adjusted by
// changing numbers here and re-running, and so nothing in the repository is a
// binary nobody can edit.
//
// One script rather than two. An earlier pair drifted apart: the sheet grew a
// bleed and a layout table that the icon it was choosing from never had.
//
// Usage:
//   swift scripts/make-icon.swift icon <output.png> [size]   the chosen icon
//   swift scripts/make-icon.swift sheet <directory> [size]   every variant

import CoreGraphics
import CoreImage
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

typealias Colour = (r: Double, g: Double, b: Double)
typealias Twirl = (x: Double, y: Double, radius: Double, angle: Double)

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

/// How the blobs are laid out before anything twists them.
///
/// The layout matters more than the colour. Twenty spirals in twenty palettes
/// look like one icon tinted twenty ways, which is what the first attempt was.
enum Layout: CaseIterable {
  case spiral
  case scatter
  case ring
  case clusters
  case phyllotaxis
  case band
}

/// What happens to the picture after the blobs and the twists.
///
/// The parameter sweeps ran out of road: with the bleed on, the blobs cover
/// everything and ground colour stopped mattering. These change the picture
/// rather than the numbers behind it.
enum Effect {
  case none
  case kaleidoscope
  case crystallize
  case posterize
  case bloom
  case zoom
  case pixellate
  case hueSpin
}

struct Variant {
  var name: String
  let ground: Colour
  let palette: [Colour]
  let layout: Layout
  let count: Int
  let alpha: (Double, Double)
  let radius: (Double, Double)
  /// Twisting pulls the colour boundaries into each other and makes a shape.
  /// Left off, the gradients stay broad, which is what survives being shrunk
  /// to a home screen.
  let twist: Bool
  /// `.screen` is the usual one: overlaps brighten and shift hue. The others
  /// are here because they break that habit.
  let blend: CGBlendMode
  let effect: Effect
  let vibrance: Double
  let saturation: Double
  let brightness: Double
  let seed: UInt64
}

/// The choices a layout makes once, for the whole icon.
///
/// Drawn before the loop rather than inside it. Taking a fresh turn count for
/// every blob was the first attempt, and it meant the spiral had a different
/// pitch at each blob, which is not a spiral.
struct Arrangement {
  let phase: Double
  let turns: Double
  let direction: Double
  let spread: Double

  init(random: inout Random) {
    phase = random.next(0, 2 * Double.pi)
    turns = random.next(1.4, 4.6)
    direction = random.next() < 0.5 ? -1 : 1
    spread = random.next(0.30, 0.48)
  }
}

/// Where a blob goes, in fractions of the side.
func place(
  _ layout: Layout,
  index: Int,
  of count: Int,
  arrangement: Arrangement,
  random: inout Random
) -> (Double, Double) {
  let progress = Double(index) / Double(max(1, count - 1))
  switch layout {
  case .spiral:
    let angle = arrangement.phase + arrangement.direction * progress * arrangement.turns * 2 * Double.pi
    let arm = 0.14 + progress * arrangement.spread
    let jitter = random.next(0.86, 1.14)
    return (0.5 + cos(angle) * arm * jitter, 0.5 + sin(angle) * arm * jitter)
  case .scatter:
    return (random.next(0.12, 0.88), random.next(0.12, 0.88))
  case .ring:
    let angle = arrangement.phase + progress * 2 * Double.pi + random.next(-0.3, 0.3)
    return (0.5 + cos(angle) * arrangement.spread, 0.5 + sin(angle) * arrangement.spread)
  case .clusters:
    // Two knots of colour rather than one sweep.
    let first = index % 2 == 0
    let cx = first ? 0.34 : 0.68
    let cy = first ? 0.66 : 0.32
    return (cx + random.next(-0.18, 0.18), cy + random.next(-0.18, 0.18))
  case .phyllotaxis:
    // The angle a sunflower uses. Nothing lines up with anything, which is
    // what stops it reading as a spiral. The phase turns the whole head and
    // the spread decides how far out it reaches.
    let golden = 2.399_963_229_728_653
    let angle = arrangement.phase + Double(index) * golden
    let arm = arrangement.spread * (Double(index) / Double(count)).squareRoot()
    let jitter = random.next(0.94, 1.06)
    return (0.5 + cos(angle) * arm * jitter, 0.5 + sin(angle) * arm * jitter)
  case .band:
    let along = progress + random.next(-0.06, 0.06)
    let across = random.next(-0.16, 0.16)
    let tilt = arrangement.direction * 0.7
    return (0.1 + along * 0.8 + across * sin(tilt), 0.1 + along * 0.8 * tilt + 0.4 + across)
  }
}

/// A different number of twists, in different places, at different strengths.
func twirls(random: inout Random) -> [Twirl] {
  let count = Int(random.next(1, 5.99))
  return (0 ..< count).map { _ in
    (
      x: random.next(0.22, 0.78),
      y: random.next(0.22, 0.78),
      radius: random.next(0.22, 0.80),
      angle: random.next(1.6, 7.5) * (random.next() < 0.5 ? -1 : 1)
    )
  }
}

// Palettes.
let spectrum: [Colour] = [
  (1.00, 0.52, 0.14), (1.00, 0.28, 0.54), (0.88, 0.38, 0.96),
  (0.46, 0.48, 1.00), (0.18, 0.86, 0.96), (0.36, 0.96, 0.62), (1.00, 0.84, 0.28),
]
let warm: [Colour] = [
  (1.00, 0.62, 0.20), (1.00, 0.36, 0.32), (1.00, 0.80, 0.30),
  (0.98, 0.44, 0.62), (1.00, 0.54, 0.10),
]
let cool: [Colour] = [
  (0.30, 0.70, 1.00), (0.24, 0.92, 0.88), (0.52, 0.52, 1.00),
  (0.40, 0.96, 0.70), (0.70, 0.56, 1.00),
]
let sunset: [Colour] = [
  (1.00, 0.46, 0.22), (1.00, 0.30, 0.48), (0.86, 0.34, 0.86),
  (1.00, 0.74, 0.32), (0.62, 0.36, 0.94),
]
let coffee: [Colour] = [
  (1.00, 0.70, 0.34), (0.94, 0.48, 0.22), (1.00, 0.86, 0.60),
  (0.78, 0.36, 0.20), (1.00, 0.58, 0.36),
]
let neon: [Colour] = [
  (0.20, 1.00, 0.86), (1.00, 0.24, 0.72), (0.62, 1.00, 0.30),
  (0.36, 0.62, 1.00), (1.00, 0.90, 0.24),
]

let berry: [Colour] = [
  (1.00, 0.24, 0.66), (0.72, 0.30, 1.00), (1.00, 0.44, 0.86),
  (0.52, 0.24, 0.92), (1.00, 0.62, 0.78),
]
let forest: [Colour] = [
  (0.36, 1.00, 0.52), (0.16, 0.86, 0.70), (0.72, 1.00, 0.34),
  (0.20, 0.68, 0.56), (0.56, 0.96, 0.78),
]
let acid: [Colour] = [
  (0.70, 1.00, 0.22), (0.16, 1.00, 0.78), (1.00, 0.94, 0.20),
  (0.30, 0.86, 1.00), (0.86, 1.00, 0.40),
]
let ice: [Colour] = [
  (0.56, 0.92, 1.00), (0.78, 0.84, 1.00), (0.40, 1.00, 0.94),
  (0.92, 0.94, 1.00), (0.50, 0.70, 1.00),
]

/// Kept. Oliver picked these out of the sheets, and the numbers are here so
/// they survive the next round.
///
/// Tight radius is what makes them: the blobs stay small enough that the
/// golden angle shows as texture rather than melting into one wash. The
/// second is the first with the ground and the alpha pulled down.
let pinnedNeonTight = Variant(
  name: "pinned neon tight", ground: (0.10, 0.06, 0.26), palette: neon,
  layout: .phyllotaxis, count: 30, alpha: (0.60, 0.86), radius: (0.12, 0.22),
  twist: false, blend: .screen, effect: .none,
  vibrance: 0.62, saturation: 1.28, brightness: 0.06, seed: 21_004
)

let pinnedNeonDark = Variant(
  name: "pinned neon dark", ground: (0.06, 0.04, 0.17), palette: neon,
  layout: .phyllotaxis, count: 30, alpha: (0.50, 0.74), radius: (0.12, 0.22),
  twist: false, blend: .screen, effect: .none,
  vibrance: 0.62, saturation: 1.28, brightness: 0.03, seed: 21_004
)

let pinnedHexPixels = Variant(
  name: "pinned hex pixels", ground: (0.06, 0.04, 0.17), palette: neon,
  layout: .phyllotaxis, count: 30, alpha: (0.50, 0.74), radius: (0.12, 0.22),
  twist: false, blend: .screen, effect: .pixellate,
  vibrance: 0.62, saturation: 1.28, brightness: 0.03, seed: 21_004
)

/// Numbers the entries for the sheet, so a choice can be named.
func numbered(_ index: Int, _ variant: Variant, _ name: String) -> Variant {
  var copy = variant
  copy.name = "\(index < 10 ? "0" : "")\(index) \(name)"
  return copy
}

let variants: [Variant] = [
  numbered(1, pinnedNeonTight, "PINNED neon tight"),
  numbered(2, pinnedNeonDark, "PINNED neon dark"),
  numbered(3, pinnedHexPixels, "PINNED hex pixels"),
  Variant(name: "04 kaleido berry", ground: (0.08, 0.03, 0.20), palette: berry,
          layout: .ring, count: 20, alpha: (0.60, 0.86), radius: (0.18, 0.32),
          twist: false, blend: .screen, effect: .kaleidoscope,
          vibrance: 0.62, saturation: 1.28, brightness: 0.03, seed: 40101),
  Variant(name: "05 kaleido forest", ground: (0.02, 0.10, 0.12), palette: forest,
          layout: .band, count: 24, alpha: (0.58, 0.84), radius: (0.16, 0.30),
          twist: false, blend: .screen, effect: .kaleidoscope,
          vibrance: 0.62, saturation: 1.28, brightness: 0.03, seed: 40202),
  Variant(name: "06 crystal spiral", ground: (0.05, 0.03, 0.16), palette: spectrum,
          layout: .spiral, count: 28, alpha: (0.56, 0.80), radius: (0.14, 0.26),
          twist: true, blend: .screen, effect: .crystallize,
          vibrance: 0.62, saturation: 1.28, brightness: 0.03, seed: 40303),
  Variant(name: "07 crystal ice big", ground: (0.04, 0.06, 0.22), palette: ice,
          layout: .clusters, count: 7, alpha: (0.74, 0.96), radius: (0.34, 0.56),
          twist: false, blend: .screen, effect: .crystallize,
          vibrance: 0.62, saturation: 1.28, brightness: 0.03, seed: 40404),
  Variant(name: "08 poster sunset", ground: (0.16, 0.05, 0.22), palette: sunset,
          layout: .band, count: 18, alpha: (0.64, 0.90), radius: (0.20, 0.36),
          twist: false, blend: .screen, effect: .posterize,
          vibrance: 0.62, saturation: 1.28, brightness: 0.03, seed: 40505),
  Variant(name: "09 poster cool tiny", ground: (0.03, 0.05, 0.18), palette: cool,
          layout: .scatter, count: 70, alpha: (0.40, 0.60), radius: (0.07, 0.14),
          twist: false, blend: .screen, effect: .posterize,
          vibrance: 0.62, saturation: 1.28, brightness: 0.03, seed: 40606),
  Variant(name: "10 hex berry ring", ground: (0.09, 0.03, 0.20), palette: berry,
          layout: .ring, count: 22, alpha: (0.56, 0.82), radius: (0.16, 0.30),
          twist: false, blend: .screen, effect: .pixellate,
          vibrance: 0.62, saturation: 1.28, brightness: 0.03, seed: 40707),
  Variant(name: "11 hex spectrum", ground: (0.05, 0.04, 0.14), palette: spectrum,
          layout: .phyllotaxis, count: 60, alpha: (0.44, 0.66), radius: (0.10, 0.20),
          twist: false, blend: .screen, effect: .pixellate,
          vibrance: 0.62, saturation: 1.28, brightness: 0.03, seed: 40808),
  Variant(name: "12 bloom acid", ground: (0.03, 0.03, 0.10), palette: acid,
          layout: .clusters, count: 20, alpha: (0.42, 0.64), radius: (0.20, 0.36),
          twist: false, blend: .screen, effect: .bloom,
          vibrance: 0.62, saturation: 1.28, brightness: 0.03, seed: 40909),
  Variant(name: "13 zoom forest", ground: (0.02, 0.09, 0.13), palette: forest,
          layout: .spiral, count: 26, alpha: (0.54, 0.78), radius: (0.14, 0.26),
          twist: true, blend: .screen, effect: .zoom,
          vibrance: 0.62, saturation: 1.28, brightness: 0.03, seed: 41010),
  Variant(name: "14 hue warm", ground: (0.20, 0.08, 0.14), palette: warm,
          layout: .scatter, count: 24, alpha: (0.58, 0.84), radius: (0.18, 0.32),
          twist: false, blend: .screen, effect: .hueSpin,
          vibrance: 0.62, saturation: 1.28, brightness: 0.03, seed: 41111),
  Variant(name: "15 dodge acid", ground: (0.04, 0.03, 0.10), palette: acid,
          layout: .ring, count: 18, alpha: (0.26, 0.44), radius: (0.16, 0.30),
          twist: false, blend: .colorDodge, effect: .none,
          vibrance: 0.62, saturation: 1.28, brightness: 0.03, seed: 41212),
  Variant(name: "16 dodge ice", ground: (0.03, 0.04, 0.14), palette: ice,
          layout: .phyllotaxis, count: 26, alpha: (0.24, 0.40), radius: (0.14, 0.26),
          twist: false, blend: .colorDodge, effect: .none,
          vibrance: 0.62, saturation: 1.28, brightness: 0.03, seed: 41313),
  Variant(name: "17 hardlight forest", ground: (0.10, 0.14, 0.26), palette: forest,
          layout: .band, count: 22, alpha: (0.62, 0.88), radius: (0.18, 0.32),
          twist: false, blend: .hardLight, effect: .none,
          vibrance: 0.62, saturation: 1.28, brightness: 0.03, seed: 41414),
  Variant(name: "18 swarm spectrum", ground: (0.02, 0.02, 0.08), palette: spectrum,
          layout: .scatter, count: 120, alpha: (0.28, 0.48), radius: (0.04, 0.10),
          twist: false, blend: .screen, effect: .none,
          vibrance: 0.62, saturation: 1.28, brightness: 0.03, seed: 41515),
  Variant(name: "19 giants berry", ground: (0.05, 0.02, 0.16), palette: berry,
          layout: .clusters, count: 4, alpha: (0.82, 0.99), radius: (0.46, 0.74),
          twist: false, blend: .screen, effect: .posterize,
          vibrance: 0.62, saturation: 1.28, brightness: 0.03, seed: 41616),
  Variant(name: "20 twist kaleido", ground: (0.04, 0.05, 0.20), palette: cool,
          layout: .spiral, count: 26, alpha: (0.56, 0.82), radius: (0.14, 0.26),
          twist: true, blend: .screen, effect: .kaleidoscope,
          vibrance: 0.62, saturation: 1.28, brightness: 0.03, seed: 41717),
]

let space = CGColorSpaceCreateDeviceRGB()
let ciContext = CIContext(options: [.workingColorSpace: space])

/// How much wider the drawing is than the icon cut out of it.
///
/// Every blob used to sit inside the frame, so the border was whatever ground
/// colour showed between them and the edge, and the corners were flat. Drawing
/// wider and cutting the middle out puts blobs past the edge, so colour runs
/// off all four sides instead of stopping short of them.
let bleed = 1.7

/// One filter, chosen by name, with numbers that suit a 1024 icon.
func apply(_ effect: Effect, to image: CIImage, canvas: Int) -> CIImage {
  let middle = CIVector(x: Double(canvas) / 2, y: Double(canvas) / 2)
  let size = Double(canvas)
  switch effect {
  case .none:
    return image
  case .kaleidoscope:
    let filter = CIFilter(name: "CIKaleidoscope")!
    filter.setValue(image, forKey: kCIInputImageKey)
    filter.setValue(6, forKey: "inputCount")
    filter.setValue(middle, forKey: kCIInputCenterKey)
    return filter.outputImage!.clampedToExtent()
  case .crystallize:
    let filter = CIFilter(name: "CICrystallize")!
    filter.setValue(image, forKey: kCIInputImageKey)
    filter.setValue(size * 0.06, forKey: kCIInputRadiusKey)
    filter.setValue(middle, forKey: kCIInputCenterKey)
    return filter.outputImage!.clampedToExtent()
  case .posterize:
    let filter = CIFilter(name: "CIColorPosterize")!
    filter.setValue(image, forKey: kCIInputImageKey)
    filter.setValue(5, forKey: "inputLevels")
    return filter.outputImage!
  case .bloom:
    let filter = CIFilter(name: "CIBloom")!
    filter.setValue(image, forKey: kCIInputImageKey)
    filter.setValue(size * 0.08, forKey: kCIInputRadiusKey)
    filter.setValue(1.4, forKey: kCIInputIntensityKey)
    return filter.outputImage!.clampedToExtent()
  case .zoom:
    let filter = CIFilter(name: "CIZoomBlur")!
    filter.setValue(image, forKey: kCIInputImageKey)
    filter.setValue(middle, forKey: kCIInputCenterKey)
    filter.setValue(size * 0.04, forKey: "inputAmount")
    return filter.outputImage!.clampedToExtent()
  case .pixellate:
    let filter = CIFilter(name: "CIHexagonalPixellate")!
    filter.setValue(image, forKey: kCIInputImageKey)
    filter.setValue(middle, forKey: kCIInputCenterKey)
    filter.setValue(size * 0.035, forKey: kCIInputScaleKey)
    return filter.outputImage!.clampedToExtent()
  case .hueSpin:
    let filter = CIFilter(name: "CIHueAdjust")!
    filter.setValue(image, forKey: kCIInputImageKey)
    filter.setValue(2.1, forKey: kCIInputAngleKey)
    return filter.outputImage!
  }
}

func render(_ variant: Variant, side: Int) -> CGImage? {
  let canvas = Int(Double(side) * bleed)
  guard let context = CGContext(
    data: nil, width: canvas, height: canvas, bitsPerComponent: 8, bytesPerRow: 0,
    space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
  ) else { return nil }

  context.setFillColor(CGColor(
    red: variant.ground.r, green: variant.ground.g, blue: variant.ground.b, alpha: 1
  ))
  context.fill(CGRect(x: 0, y: 0, width: canvas, height: canvas))
  context.setBlendMode(variant.blend)

  var random = Random(state: variant.seed)
  // The layout and the twists come from the seed, so two variants differ in
  // shape rather than only in colour.
  let layout = variant.layout
  let arrangement = Arrangement(random: &random)
  let twists = variant.twist ? twirls(random: &random) : []

  for index in 0 ..< variant.count {
    let (fx, fy) = place(
      layout, index: index, of: variant.count, arrangement: arrangement, random: &random
    )
    let x = fx * Double(canvas)
    let y = fy * Double(canvas)
    let radius = Double(canvas) * random.next(variant.radius.0, variant.radius.1)
    let colour = variant.palette[index % variant.palette.count]
    let inner = CGColor(
      red: colour.r, green: colour.g, blue: colour.b,
      alpha: random.next(variant.alpha.0, variant.alpha.1)
    )
    let outer = CGColor(red: colour.r, green: colour.g, blue: colour.b, alpha: 0)
    guard let gradient = CGGradient(
      colorsSpace: space, colors: [inner, outer] as CFArray, locations: [0, 1]
    ) else { continue }
    context.drawRadialGradient(
      gradient,
      startCenter: CGPoint(x: x, y: y), startRadius: 0,
      endCenter: CGPoint(x: x, y: y), endRadius: radius, options: []
    )
  }

  guard let flat = context.makeImage() else { return nil }
  var image = CIImage(cgImage: flat).clampedToExtent()

  for twirl in twists {
    let filter = CIFilter(name: "CITwirlDistortion")!
    filter.setValue(image, forKey: kCIInputImageKey)
    filter.setValue(
      CIVector(x: Double(canvas) * twirl.x, y: Double(canvas) * twirl.y),
      forKey: kCIInputCenterKey
    )
    filter.setValue(Double(canvas) * twirl.radius, forKey: kCIInputRadiusKey)
    filter.setValue(twirl.angle, forKey: kCIInputAngleKey)
    image = filter.outputImage!.clampedToExtent()
  }

  image = apply(variant.effect, to: image, canvas: canvas)

  let vibrance = CIFilter(name: "CIVibrance")!
  vibrance.setValue(image, forKey: kCIInputImageKey)
  vibrance.setValue(variant.vibrance, forKey: "inputAmount")
  image = vibrance.outputImage!

  let controls = CIFilter(name: "CIColorControls")!
  controls.setValue(image, forKey: kCIInputImageKey)
  controls.setValue(variant.saturation, forKey: kCIInputSaturationKey)
  controls.setValue(variant.brightness, forKey: kCIInputBrightnessKey)
  image = controls.outputImage!

  // Cut the middle out. The rest ran off the edges, which is the point.
  let inset = Double(canvas - side) / 2
  return ciContext.createCGImage(
    image, from: CGRect(x: inset, y: inset, width: Double(side), height: Double(side))
  )
}

func write(_ image: CGImage, to path: String) {
  let url = URL(fileURLWithPath: path)
  guard let destination = CGImageDestinationCreateWithURL(
    url as CFURL, UTType.png.identifier as CFString, 1, nil
  ) else { return }
  CGImageDestinationAddImage(destination, image, nil)
  _ = CGImageDestinationFinalize(destination)
}

/// What the app ships. Change this line to change the icon.
let chosen = pinnedHexPixels

let mode = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon"

if mode == "icon" {
  let path = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "icon.png"
  let side = CommandLine.arguments.count > 3 ? Int(CommandLine.arguments[3]) ?? 1024 : 1024
  guard let image = render(chosen, side: side) else {
    FileHandle.standardError.write(Data("cannot draw the icon\n".utf8))
    exit(1)
  }
  write(image, to: path)
  print("wrote \(path) from \(chosen.name)")
  exit(0)
}

let directory = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "."
let side = CommandLine.arguments.count > 3 ? Int(CommandLine.arguments[3]) ?? 512 : 512
try? FileManager.default.createDirectory(
  atPath: directory, withIntermediateDirectories: true
)

var rendered: [CGImage] = []
for (index, variant) in variants.enumerated() {
  guard let image = render(variant, side: side) else { continue }
  rendered.append(image)
  write(image, to: "\(directory)/icon-\(String(format: "%02d", index + 1)).png")
}

// The contact sheet. Four across, five down, numbered, so a choice can be
// named rather than pointed at.
let cell = 300
let gap = 16
let label = 44
let columns = 4
let rows = (rendered.count + columns - 1) / columns
let sheetWidth = columns * cell + (columns + 1) * gap
let sheetHeight = rows * (cell + label) + (rows + 1) * gap

if let sheet = CGContext(
  data: nil, width: sheetWidth, height: sheetHeight, bitsPerComponent: 8, bytesPerRow: 0,
  space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) {
  sheet.setFillColor(CGColor(red: 0.97, green: 0.97, blue: 0.98, alpha: 1))
  sheet.fill(CGRect(x: 0, y: 0, width: sheetWidth, height: sheetHeight))

  for (index, image) in rendered.enumerated() {
    let column = index % columns
    let row = index / columns
    let x = gap + column * (cell + gap)
    let y = sheetHeight - (gap + (row + 1) * (cell + label) + row * gap) + label
    sheet.draw(image, in: CGRect(x: x, y: y, width: cell, height: cell))

    // CoreText keys rather than AppKit ones, so this stays a script that runs
    // with nothing but the system frameworks.
    let text = variants[index].name
    let font = CTFontCreateWithName("Helvetica" as CFString, 26, nil)
    let attributes: [CFString: Any] = [
      kCTFontAttributeName: font,
      kCTForegroundColorAttributeName: CGColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 1),
    ]
    guard let attributed = CFAttributedStringCreate(
      nil, text as CFString, attributes as CFDictionary
    ) else { continue }
    let line = CTLineCreateWithAttributedString(attributed)
    sheet.textPosition = CGPoint(x: Double(x), y: Double(y) - 32)
    CTLineDraw(line, sheet)
  }

  if let image = sheet.makeImage() {
    write(image, to: "\(directory)/sheet.png")
  }
}

print("wrote \(rendered.count) icons and a sheet to \(directory)")
