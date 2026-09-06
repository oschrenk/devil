/// How the numbers read on screen.
///
/// Here rather than in the views, because the tests assert on the same strings
/// the app shows. A weight that reads one way in a test and another on the
/// phone is a weight nobody has really checked.
public enum Format {
  /// `50`, `112.5`. No trailing zero on a whole number, and one decimal at
  /// most, which is all the scale resolves.
  public static func number(_ value: Double) -> String {
    let rounded = (value * 10).rounded() / 10
    if rounded == rounded.rounded() {
      return "\(Int(rounded))"
    }
    return "\(rounded)"
  }

  public static func grams(_ value: Double) -> String {
    "\(number(value)) g"
  }

  public static func degrees(_ value: Double) -> String {
    "\(number(value)) °C"
  }

  /// `1 : 16.6` with a vinculum over the six.
  ///
  /// The ratio is 50/3 exactly: the dose and the water are both linear in the
  /// same term, so it repeats rather than rounds. Written as 16.7 it reads like
  /// a measurement someone took. The overline says it is a third.
  public static func ratio(_ value: Double) -> String {
    let repeating = 50.0 / 3.0
    if abs(value - repeating) < 0.000_001 {
      // U+0305 COMBINING OVERLINE, which sits on the character before it.
      return "1 : 16.6\u{0305}"
    }
    return "1 : \(number(value))"
  }

  /// `7.9`, `8.0`. Always one decimal, because that digit is the click on the
  /// grinder and dropping it turns 8.0 into a different setting.
  public static func grind(_ value: Double) -> String {
    let rounded = (value * 10).rounded() / 10
    let whole = Int(rounded)
    let tenth = Int((abs(rounded) * 10).rounded()) % 10
    return "\(whole).\(tenth)"
  }
}
