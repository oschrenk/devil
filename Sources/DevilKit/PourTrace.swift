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

  /// The reading in the middle by weight, and a real reading rather than an
  /// average of several. An averaged point sits where the scale never read.
  ///
  /// This is what removes the spikes. A single wrong reading is outvoted by
  /// the ones either side of it, where a mean would be dragged upwards by it
  /// and a first-or-last pick would sometimes land on it.
  static func median(of samples: [PourSample]) -> PourSample? {
    guard !samples.isEmpty else { return nil }
    return samples.sorted { $0.grams < $1.grams }[(samples.count - 1) / 2]
  }

  /// Grams a second, over the readings inside `window` ending at `seconds`.
  ///
  /// A difference between two readings ten milliseconds apart is mostly noise,
  /// so the rate is taken across a window rather than between neighbours. Each
  /// end of that window is a median of three, because a rate read from single
  /// endpoints is wrong by the whole of any bad reading that lands on one.
  public func flow(at seconds: Double, window: Double = 0.5) -> Double? {
    let inWindow = samples.filter { $0.seconds > seconds - window && $0.seconds <= seconds }
    guard inWindow.count > 1,
          let first = Self.median(of: Array(inWindow.prefix(3))),
          let last = Self.median(of: Array(inWindow.suffix(3)))
    else { return nil }
    let span = last.seconds - first.seconds
    guard span > 0 else { return nil }
    return (last.grams - first.grams) / span
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

  /// How wide a bucket has to be to keep the drawing under `limit` points.
  ///
  /// A whole number of seconds, so the buckets a brew is cut into do not move
  /// as it goes on. A width derived from the reading count would change with
  /// every reading, and every drawn point would land somewhere new each time.
  static func bucketWidth(span: Double, limit: Int) -> Double {
    guard limit > 0, span > 0 else { return 1 }
    return max(1, (span / Double(limit)).rounded(.up))
  }

  /// The trace at a size a chart can draw, with the gaps kept.
  ///
  /// One point per bucket of time, each the median of the readings in it.
  /// Cutting by time rather than by count is what stops the line flickering:
  /// a bucket already full keeps the same readings and yields the same point
  /// no matter how much arrives later, so only the newest point ever moves.
  /// Picking every nth reading instead re-picks the whole line on each pass,
  /// and a bad reading blinks in and out as the spacing slides over it.
  ///
  /// A reading outside `range` is pulled to the nearer edge rather than
  /// dropped. Lifting the server reads well below zero, and a line that leaves
  /// the frame either draws over the rest of the screen or vanishes and looks
  /// like a dropout. Held at the edge it stays visible and stays in its box,
  /// while the trace itself keeps the reading the scale actually sent.
  public func drawableSegments(
    limit: Int,
    maxGap: Double = 1,
    within range: ClosedRange<Double>? = nil
  ) -> [[PourSample]] {
    let span = (samples.last?.seconds ?? 0) - (samples.first?.seconds ?? 0)
    let width = Self.bucketWidth(span: span, limit: limit)

    return segments(maxGap: maxGap).map { part in
      var points: [PourSample] = []
      var bucket: [PourSample] = []
      var index = (part.first?.seconds ?? 0) / width

      for sample in part {
        let next = (sample.seconds / width).rounded(.down)
        if next != index, let point = Self.median(of: bucket) {
          points.append(point)
          bucket = []
        }
        index = next
        bucket.append(sample)
      }
      if let point = Self.median(of: bucket) {
        points.append(point)
      }

      guard let range else { return points }
      return points.map {
        let held = min(max($0.grams, range.lowerBound), range.upperBound)
        return PourSample(seconds: $0.seconds, grams: held)
      }
    }
  }
}
