/// The burr set the grind setting refers to.
///
/// A grind number means nothing on its own. `7.9` is a Hario-paper pour-over
/// on the K-Ultra and something else entirely on the Ode, so a brew log that
/// records the number without the grinder records half a fact.
public struct Grinder: Equatable, Hashable, Sendable {
  public var name: String
  /// What the dial accepts, in the units printed on it.
  public var grindRange: ClosedRange<Double>

  public init(name: String, grindRange: ClosedRange<Double>) {
    self.name = name
    self.grindRange = grindRange
  }

  /// The nearest setting this grinder can actually be set to.
  public func clamped(_ setting: Double) -> Double {
    min(max(setting, grindRange.lowerBound), grindRange.upperBound)
  }
}

public extension Grinder {
  /// The range here is the part of the dial this brewer uses, which is where
  /// the number came from before `Grinder` existed.
  static let oneZpressoKUltra = Grinder(name: "1Zpresso K-Ultra", grindRange: 6.0 ... 10.0)

  /// The whole dial rather than a pour-over window, so no setting you have
  /// actually used is unreachable.
  static let fellowOdeSSP = Grinder(name: "Fellow Ode with SSP", grindRange: 1.0 ... 11.0)

  static let all: [Grinder] = [.oneZpressoKUltra, .fellowOdeSSP]
}
