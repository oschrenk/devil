/// The paper the brew runs through, and the grind that suits it.
///
/// Grind is a property of the filter rather than of the recipe. Abaca paper
/// flows faster than Hario's, so it takes a finer setting to hold the same
/// contact time. Storing the setting on the recipe would make it look like one
/// number, and it is two.
public struct Filter: Equatable, Sendable {
  public var name: String
  /// On the 1Zpresso K-Ultra. Lower is finer.
  public var grindSetting: String

  public init(name: String, grindSetting: String) {
    self.name = name
    self.grindSetting = grindSetting
  }
}

public extension Filter {
  static let harioV60Size02 = Filter(name: "Hario V60 02", grindSetting: "7.9")
  static let abaca = Filter(name: "Abaca", grindSetting: "7.5")
}
