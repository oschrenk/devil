/// The recipe this app exists to drive.
///
/// A placeholder while the scaffolding is proven. The real model - dose, water
/// plan, pour schedule and the temperatures that scale with them - lands with
/// the tasks that follow. What it carries today is enough for the app target to
/// import the package and for a test to assert on the result, so the link
/// between the two is proven rather than assumed.
public enum Brew {
  /// The name shown on the first screen.
  public static let name = "Devil"

  /// The brewer the recipe is written for.
  public static let brewer = "Hario Switch"
}
