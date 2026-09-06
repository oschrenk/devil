/// Tap and demineralized water held together, in grams.
///
/// The kettle is one liquid, not two stacked layers. A pour therefore removes
/// both kinds in the ratio the kettle currently holds, and whatever stays
/// behind is blended in that same ratio. Getting this wrong is what makes a
/// recipe look like it delivers 50/50 when it does not.
public struct Blend: Equatable, Sendable {
  public private(set) var tap: Double
  public private(set) var demineralized: Double

  public init(tap: Double, demineralized: Double) {
    self.tap = tap
    self.demineralized = demineralized
  }

  public static let empty = Blend(tap: 0, demineralized: 0)

  public var total: Double {
    tap + demineralized
  }

  /// The share of the blend that is tap water, from 0 to 1. Zero when empty.
  public var tapFraction: Double {
    total == 0 ? 0 : tap / total
  }

  public mutating func addDemineralized(_ grams: Double) {
    demineralized += grams
  }

  public mutating func add(_ other: Blend) {
    tap += other.tap
    demineralized += other.demineralized
  }

  /// Removes `grams` from the blend and returns what came out.
  ///
  /// Asking for more than the blend holds pours everything and returns that,
  /// rather than inventing water or trapping the caller in an error path. A
  /// kettle that runs dry mid-recipe is a recipe fault, and the recipe tests
  /// are where it should surface.
  @discardableResult
  public mutating func pour(_ grams: Double) -> Blend {
    let taken = Swift.min(grams, total)
    let fraction = tapFraction
    let poured = Blend(tap: taken * fraction, demineralized: taken * (1 - fraction))
    tap -= poured.tap
    demineralized -= poured.demineralized
    return poured
  }
}
