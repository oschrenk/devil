/// A point on the brew clock, counted from the first pour.
///
/// `RECIPE.md` reads in absolute times - 0:00, 0:30, 1:45 - so steps record
/// where they start rather than how long they last. Durations fall out by
/// subtracting one start from the next, and stay correct when a step moves.
public struct BrewTime: Equatable, Comparable, Hashable, Sendable {
  public let seconds: Int

  public init(seconds: Int) {
    self.seconds = seconds
  }

  public init(minutes: Int, seconds: Int) {
    self.seconds = minutes * 60 + seconds
  }

  public var minutePart: Int {
    seconds / 60
  }

  public var secondPart: Int {
    seconds % 60
  }

  /// Reads the way the recipe is written: `1:45`, never `1:5`.
  ///
  /// Padded by hand rather than with `String(format:)`, which would pull
  /// Foundation into a package that otherwise needs nothing.
  public var formatted: String {
    let padded = secondPart < 10 ? "0\(secondPart)" : "\(secondPart)"
    return "\(minutePart):\(padded)"
  }

  public static func < (lhs: BrewTime, rhs: BrewTime) -> Bool {
    lhs.seconds < rhs.seconds
  }
}
