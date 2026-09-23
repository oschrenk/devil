/// One reading from the probe, placed on the brew clock.
///
/// Five zones along the shaft, and the sensor on the handle. All degrees
/// Celsius: the wire carries tenths of a degree Fahrenheit and `DevilProbe`
/// converts, because every other temperature in a brew file is Celsius and a
/// file that mixes units is a trap.
public struct HeatSample: Equatable, Sendable, Identifiable {
  public let seconds: Double
  /// Zone one first, at the pointed end. No zone has a name, because naming
  /// one is what led to reading the wrong field in the first place.
  public let zones: [Double]
  /// On the handle, and it drifts. Heat conducts up the shaft, so this climbs
  /// with the brew rather than reporting the room.
  public let ambient: Double

  public var id: Double {
    seconds
  }

  public init(seconds: Double, zones: [Double], ambient: Double) {
    self.seconds = seconds
    self.zones = zones
    self.ambient = ambient
  }
}

/// The shape of the heat through a brew, kept as it happens.
///
/// The probe reports about every two seconds while a value is moving and every
/// ten while it holds, so a three-minute brew is roughly ninety readings
/// against the pour trace's two thousand. Small enough to keep whole.
public struct HeatTrace: Equatable, Sendable {
  public private(set) var samples: [HeatSample] = []

  public init() {}

  public var isEmpty: Bool {
    samples.isEmpty
  }

  /// Readings that arrive out of order, or twice within the same instant, are
  /// dropped, for the reason `PourTrace` drops them: a trace that can go
  /// backwards in time draws as a scribble.
  public mutating func append(seconds: Double, zones: [Double], ambient: Double) {
    guard !zones.isEmpty else { return }
    if let last = samples.last, seconds <= last.seconds {
      return
    }
    samples.append(HeatSample(seconds: seconds, zones: zones, ambient: ambient))
  }

  /// One zone across the brew, for drawing. Out of range gives nothing rather
  /// than a partial line.
  public func zone(_ index: Int) -> [PourSample] {
    guard samples.allSatisfy({ index >= 0 && index < $0.zones.count }) else { return [] }
    return samples.map { PourSample(seconds: $0.seconds, grams: $0.zones[index]) }
  }

  /// The warmest and coolest anything reached, which is what a chart axis
  /// wants. `nil` while there is nothing to draw.
  public var range: ClosedRange<Double>? {
    let all = samples.flatMap(\.zones)
    guard let low = all.min(), let high = all.max() else { return nil }
    return low == high ? (low - 1) ... (high + 1) : low ... high
  }
}
