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
}
