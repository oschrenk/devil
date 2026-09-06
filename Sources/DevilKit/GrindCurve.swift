import Foundation

/// How far along a grinder's dial maps to a particle size.
///
/// The shape is two logistic curves stacked at the midpoint, fine below and
/// coarse above, with small corrections. A straight line was the first plan
/// and would have been wrong: a click near either end of a dial moves the
/// grind far less than a click in the middle.
///
/// The constants and every grinder's range come from the converter at
/// `brewfolio.app/grind-setting-to-micron`, read out of the page rather than
/// guessed. Four sample points across both grinders match it exactly.
///
/// They are estimates, as any dial-to-micron table is. What they buy is one
/// number that means the same thing on two grinders.
enum GrindCurve {
  static let fine = 6.761
  static let coarse = 4.0
  static let fineBoost = 1.405
  static let coarseBump = 0.007_894_736_842_105_263
  static let coarseSkew = 0.004_105_278_550_508_305

  private static func logistic(_ position: Double, _ steepness: Double) -> Double {
    1 / (1 + exp(-steepness * (position - 0.5)))
  }

  /// A logistic pulled back to run from 0 to 1 across its own range.
  private static func normalized(_ position: Double, _ steepness: Double) -> Double {
    let held = min(1, max(0, position))
    let low = logistic(0, steepness)
    let high = logistic(1, steepness)
    return (logistic(held, steepness) - low) / (high - low)
  }

  /// Where a dial position sits between the finest and coarsest, from 0 to 1.
  static func at(_ position: Double) -> Double {
    let along = min(1, max(0, position))
    if along <= 0.5 {
      let half = along * 2
      let boost = fineBoost * half * half * pow(1 - half, 2)
      return 0.5 * min(1, max(0, normalized(half, fine) + boost))
    }
    let half = (along - 0.5) * 2
    let arch = 4 * half * (1 - half)
    let bump = coarseBump * arch
    let skew = coarseSkew * (half - 0.5) * pow(arch, 3)
    return 0.5 + 0.5 * min(1, max(0, normalized(half, coarse) + bump + skew))
  }
}
