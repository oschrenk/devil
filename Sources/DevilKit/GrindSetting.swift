/// A position on a grinder's dial, as the dial itself reads it.
///
/// Numbers and clicks, not a decimal. The K-Ultra puts ten clicks between
/// numbers and the Ode puts three, so `2.5` is a real setting on one and does
/// not exist on the other. A `Double` cannot say that, and stepping one by a
/// tenth offers settings the grinder has no detent for.
public struct GrindSetting: Equatable, Hashable, Sendable {
  public var number: Int
  public var click: Int

  public init(number: Int, click: Int) {
    self.number = number
    self.click = click
  }

  /// `7.9`, which is how the dial is read aloud and written down.
  public var formatted: String {
    "\(number).\(click)"
  }
}
