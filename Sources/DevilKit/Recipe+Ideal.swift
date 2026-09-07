public extension Recipe {
  /// The pour the recipe intends, as a curve of grams against the clock.
  ///
  /// What a real pour is compared against. Every pour ramps over the seconds
  /// it is meant to take and then holds flat until the next one, which is
  /// what a scale reads when you stop pouring.
  ///
  /// The numbers behind it are the recipe's, not the drinker's. Where a real
  /// brew and this disagree, one of the two is worth changing, and having
  /// both drawn is how that gets noticed.
  var idealPour: [PourSample] {
    var points = [PourSample(seconds: 0, grams: 0)]
    var running = 0.0

    for step in steps.sorted(by: { $0.start < $1.start }) where step.poured > 0 {
      let start = Double(step.start.seconds)
      // Flat from wherever the last pour ended up to where this one starts.
      if points.last?.seconds != start {
        points.append(PourSample(seconds: start, grams: running))
      }
      running += step.poured
      points.append(PourSample(seconds: start + step.pourSeconds, grams: running))
    }

    let end = Double(totalTime.seconds)
    if let last = points.last, last.seconds < end {
      points.append(PourSample(seconds: end, grams: running))
    }
    return points
  }
}
