/// The paper the brew runs through, and the grind it usually wants.
///
/// The setting here is a starting point, not a rule. Abaca paper flows faster
/// than Hario's and takes a finer grind to hold the same contact time, but the
/// number that actually works moves with the beans, so `BrewSettings` carries
/// the one in force and this carries the one to start from.
public struct Filter: Equatable, Hashable, Sendable {
  public var name: String
  /// On the 1Zpresso K-Ultra. Lower is finer.
  public var defaultGrind: Double

  public init(name: String, defaultGrind: Double) {
    self.name = name
    self.defaultGrind = defaultGrind
  }
}

public extension Filter {
  static let harioV60Size02 = Filter(name: "Hario V60 02", defaultGrind: 7.9)
  static let abaca = Filter(name: "Abaca", defaultGrind: 7.5)
}
