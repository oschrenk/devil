/// What the coffee ends up in.
///
/// A name and its empty weight, because the drink is weighed by difference.
/// The tare goes against an empty scale and the full vessel goes on it, so the
/// only way to the liquid is to subtract a number the app already knows.
public struct Vessel: Equatable, Hashable, Sendable, Identifiable {
  public var name: String
  /// Empty, in grams.
  public var weight: Double

  public var id: String {
    name
  }

  public init(name: String, weight: Double) {
    self.name = name
    self.weight = weight
  }

  /// What was poured, given what the scale reads with the vessel on it.
  ///
  /// `nil` below the vessel's own weight. A total of 50 g under a 203.4 g
  /// carafe is a vessel picked wrong or a scale not tared, and a drink of
  /// minus 153 g is a worse answer than no answer.
  public func drink(total: Double) -> Double? {
    let drink = total - weight
    guard drink > 0 else { return nil }
    return (drink * 10).rounded() / 10
  }
}

public extension Vessel {
  static let hario600 = Vessel(name: "Hario 600 ml", weight: 203.4)
  static let hario300Slim = Vessel(name: "Hario 300 ml, slim", weight: 156.9)
  static let hario300Wide = Vessel(name: "Hario 300 ml, wide", weight: 159.0)
  static let generic250 = Vessel(name: "Generic 250 ml", weight: 119.7)
  static let senseCopy = Vessel(name: "Sense Cup, copy", weight: 112.2)
  static let senseOriginal = Vessel(name: "Sense Cup, original", weight: 90.0)
  static let samaDoyo = Vessel(name: "Sama Doyo", weight: 158.9)

  /// The 600 comes first, and first is the default.
  static let all: [Vessel] = [
    .hario600, .hario300Slim, .hario300Wide,
    .generic250, .senseCopy, .senseOriginal, .samaDoyo,
  ]
}
