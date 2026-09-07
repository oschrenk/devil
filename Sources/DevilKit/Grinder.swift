/// The burrs a grind setting refers to, and how its dial maps to a size.
///
/// A dial number means nothing across grinders. `7.9` is a pour-over on the
/// K-Ultra and nothing like it on the Ode, so the app holds a size in microns
/// and each grinder says which of its own detents comes closest.
public struct Grinder: Equatable, Hashable, Sendable, Identifiable {
  public var name: String
  /// What the first number on the dial is called. Zero on the K-Ultra, one on
  /// the Ode.
  public var startNumber: Int
  /// Detents between one number and the next. Ten on the K-Ultra, three on
  /// the Ode.
  public var clicksPerNumber: Int
  /// How many detents the whole dial has.
  public var ticks: Int
  public var minMicron: Double
  public var maxMicron: Double
  /// What the published figures have to be multiplied by for this grinder.
  ///
  /// One for a grinder the figures actually describe. Aftermarket burrs cut
  /// differently at the same number, so the curve's shape survives and its
  /// size does not.
  ///
  /// A factor rather than an offset. Both fit a single measured point, and
  /// only one of them stays positive: taking 643 microns off the Ode to put
  /// its 9.1 in the right place leaves its finest setting at minus 93.
  public var micronScale: Double

  public var id: String {
    name
  }

  public init(
    name: String,
    startNumber: Int,
    clicksPerNumber: Int,
    ticks: Int,
    minMicron: Double,
    maxMicron: Double,
    micronScale: Double = 1
  ) {
    self.name = name
    self.startNumber = startNumber
    self.clicksPerNumber = clicksPerNumber
    self.ticks = ticks
    self.minMicron = minMicron
    self.maxMicron = maxMicron
    self.micronScale = micronScale
  }

  /// What this grinder can reach. The two shipped grinders overlap only
  /// between 550 and 760 microns, so a size set for one can be off the end of
  /// the other, and the app has to say so rather than round it quietly.
  public var micronRange: ClosedRange<Double> {
    minMicron * micronScale ... maxMicron * micronScale
  }

  private func tick(of setting: GrindSetting) -> Int {
    let raw = (setting.number - startNumber) * clicksPerNumber + setting.click
    return min(ticks - 1, max(0, raw))
  }

  private func setting(atTick tick: Int) -> GrindSetting {
    let safe = min(ticks - 1, max(0, tick))
    return GrindSetting(
      number: safe / clicksPerNumber + startNumber,
      click: safe % clicksPerNumber
    )
  }

  /// The particle size at one detent.
  public func micron(at setting: GrindSetting) -> Double {
    guard ticks > 1 else { return minMicron * micronScale }
    let position = Double(tick(of: setting)) / Double(ticks - 1)
    let published = minMicron + GrindCurve.at(position) * (maxMicron - minMicron)
    return published * micronScale
  }

  /// The detent that comes closest to a size.
  ///
  /// Every detent is walked rather than solved for, because the curve has no
  /// inverse worth writing and a dial has at most a hundred of them.
  public func setting(forMicron micron: Double) -> GrindSetting {
    guard ticks > 1 else { return setting(atTick: 0) }
    var best = 0
    var distance = Double.infinity
    for tick in 0 ..< ticks {
      let gap = abs(self.micron(at: setting(atTick: tick)) - micron)
      if gap < distance {
        distance = gap
        best = tick
      }
    }
    return setting(atTick: best)
  }

  /// The size one or more detents away from where you are.
  ///
  /// Stepping in microns would be arbitrary: a click near the middle of a
  /// dial moves the grind several times further than one near an end. Moving
  /// by detents means the plus button does what the grinder does.
  public func stepped(_ micron: Double, by clicks: Int) -> Double {
    let current = tick(of: setting(forMicron: micron))
    return self.micron(at: setting(atTick: current + clicks))
  }

  /// Whether a size is one this grinder can actually be set to.
  public func canReach(_ micron: Double) -> Bool {
    micronRange.contains(micron)
  }
}

public extension Grinder {
  /// Numbers 0 to 10, ten clicks each, 0 to 760 microns.
  static let oneZpressoKUltra = Grinder(
    name: "1Zpresso K-Ultra",
    startNumber: 0,
    clicksPerNumber: 10,
    ticks: 101,
    minMicron: 0,
    maxMicron: 760
  )

  /// Numbers 1 to 11, three clicks each, over a dial the published figures
  /// put at 550 to 1400 microns.
  ///
  /// Those figures describe the stock burrs, and this Ode wears SSP ones. The
  /// scale comes from one point Oliver ground and compared: 7.6 on the
  /// K-Ultra is the same coffee as 9.1 here. The K-Ultra puts 7.6 at 583
  /// microns and the stock curve puts 9.1 at 1226, so this Ode cuts to a
  /// little under half of what its dial claims.
  ///
  /// That lands its useful range at 262 to 666 microns, which agrees with
  /// pour-over sitting between 6 and 9 on the dial.
  ///
  /// One point fixes the size and says nothing about the shape. Where the two
  /// grinders disagree away from 583 microns, this is the number to correct.
  static let fellowOdeSSP = Grinder(
    name: "Fellow Ode (SSP)",
    startNumber: 1,
    clicksPerNumber: 3,
    ticks: 33,
    minMicron: 550,
    maxMicron: 1400,
    micronScale: 583.0 / 1225.6
  )

  static let all: [Grinder] = [.oneZpressoKUltra, .fellowOdeSSP]
}
