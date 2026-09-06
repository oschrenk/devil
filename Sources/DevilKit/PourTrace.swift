/// One reading from the scale, placed on the brew clock.
public struct PourSample: Equatable, Sendable, Identifiable {
  public let seconds: Double
  public let grams: Double

  public var id: Double {
    seconds
  }

  public init(seconds: Double, grams: Double) {
    self.seconds = seconds
    self.grams = grams
  }
}

/// The shape of a pour, kept as it happens.
///
/// A Pearl S reports about ten times a second, so a brew is roughly two
/// thousand readings and thirty kilobytes. Small enough to keep whole, which
/// means no thinning and no decision about what to throw away.
public struct PourTrace: Equatable, Sendable {
  public private(set) var samples: [PourSample] = []

  public init() {}

  /// Readings that arrive out of order, or twice within the same instant, are
  /// dropped. A trace that can go backwards in time draws as a scribble.
  public mutating func append(seconds: Double, grams: Double) {
    guard let last = samples.last else {
      samples.append(PourSample(seconds: seconds, grams: grams))
      return
    }
    guard seconds > last.seconds else { return }
    samples.append(PourSample(seconds: seconds, grams: grams))
  }

  /// Grams a second, over the readings inside `window` ending at `seconds`.
  ///
  /// A difference between two readings ten milliseconds apart is mostly noise,
  /// so the rate is taken across a window rather than between neighbours.
  public func flow(at seconds: Double, window: Double = 0.5) -> Double? {
    let inWindow = samples.filter { $0.seconds > seconds - window && $0.seconds <= seconds }
    guard let first = inWindow.first, let last = inWindow.last else { return nil }
    let span = last.seconds - first.seconds
    guard span > 0 else { return nil }
    return (last.grams - first.grams) / span
  }

  /// At most `limit` readings from `samples`, evenly spaced, always keeping
  /// the first and the last.
  ///
  /// Nearest-neighbour rather than an average, so every point drawn is a
  /// reading that actually happened. An averaged point sits where the scale
  /// never read, which is the wrong thing to compare two brews against.
  public static func thin(_ samples: [PourSample], to limit: Int) -> [PourSample] {
    guard limit > 1, samples.count > limit else { return samples }
    let step = Double(samples.count - 1) / Double(limit - 1)
    return (0 ..< limit).map { samples[Int((Double($0) * step).rounded())] }
  }

  /// The trace split wherever it went quiet.
  ///
  /// A scale that drops out leaves a hole, and a line drawn across it claims a
  /// steady pour through the gap. Splitting there draws the hole instead.
  public func segments(maxGap: Double = 1) -> [[PourSample]] {
    guard let first = samples.first else { return [] }
    var result: [[PourSample]] = [[first]]
    for sample in samples.dropFirst() {
      if let previous = result[result.count - 1].last, sample.seconds - previous.seconds > maxGap {
        result.append([sample])
      } else {
        result[result.count - 1].append(sample)
      }
    }
    return result
  }

  /// The trace at a size a chart can draw, with the gaps kept.
  ///
  /// Thinning is done inside each segment rather than across the whole trace.
  /// Thinning first would space the readings a second apart, and every one of
  /// those intervals would then read as a gap: a brew that never dropped out
  /// would draw as a row of disconnected specks.
  public func drawableSegments(limit: Int, maxGap: Double = 1) -> [[PourSample]] {
    let parts = segments(maxGap: maxGap)
    guard samples.count > limit, limit > 1 else { return parts }
    return parts.map { part in
      let share = Double(part.count) / Double(samples.count) * Double(limit)
      return Self.thin(part, to: max(2, Int(share.rounded())))
    }
  }
}
