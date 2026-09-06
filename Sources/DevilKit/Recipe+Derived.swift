public extension Recipe {
  /// Water poured onto the bed across the whole schedule.
  var waterThroughBed: Double {
    steps.reduce(0) { $0 + $1.poured }
  }

  /// The second half of the brew ratio, as in 1 : 16.7.
  var brewRatio: Double {
    dose == 0 ? 0 : waterThroughBed / dose
  }

  var totalTime: BrewTime {
    steps.map(\.start).max() ?? BrewTime(seconds: 0)
  }

  /// How long a step lasts, in seconds, or `nil` for the last one, which marks
  /// the end of the brew rather than a wait.
  func duration(of step: Step) -> Int? {
    guard let next = steps.first(where: { $0.start > step.start }) else { return nil }
    return next.start.seconds - step.start.seconds
  }

  /// The step in force at `seconds` on the brew clock.
  func step(atSeconds seconds: Int) -> Step? {
    steps.last { $0.start.seconds <= seconds }
  }

  /// What actually reaches the coffee, and what stays in the kettle.
  ///
  /// The recipe is walked pour by pour rather than summed, because the kettle
  /// blends. Adding the cooler part-way through changes the mix of every pour
  /// after it, and totalling the inputs cannot see that.
  var brew: (delivered: Blend, leftInKettle: Blend) {
    var kettle = kettleFill.blend
    var delivered = Blend.empty
    for step in steps.sorted(by: { $0.start < $1.start }) {
      for action in step.actions {
        switch action {
        case let .addCooler(grams):
          kettle.addDemineralized(grams)
        case let .pour(grams):
          delivered.add(kettle.pour(grams))
        case .swirl, .drain, .finish:
          continue
        }
      }
    }
    return (delivered, kettle)
  }

  /// The blend that reaches the coffee.
  var delivered: Blend {
    brew.delivered
  }

  /// What the kettle still holds when the brew ends.
  var leftInKettle: Blend {
    brew.leftInKettle
  }

  /// The kettle temperature once the cooler goes in, by weighted average.
  ///
  /// This is the water temperature, not the bed temperature. The bed has been
  /// giving up heat since the previous pour and reads lower, which is what
  /// `bedTemperatureTarget` records.
  var kettleTemperatureAfterCooler: Double {
    guard let coolerStep = steps.first(where: { $0.coolerAdded > 0 }) else {
      return brewTemperature
    }
    let pouredBefore = steps
      .filter { $0.start < coolerStep.start }
      .reduce(0) { $0 + $1.poured }
    let inKettle = kettleFill.total - pouredBefore
    let added = coolerStep.coolerAdded
    guard inKettle + added > 0 else { return brewTemperature }
    return (inKettle * brewTemperature + added * cooler.temperature) / (inKettle + added)
  }

  /// How much demineralized water Beaker A needs for the coffee to receive
  /// `target` as its tap fraction.
  ///
  /// Solved by bisection rather than algebra. The relation runs through two
  /// pours and a mid-brew addition, so an exact form is long, easy to get
  /// subtly wrong, and no more accurate than this at the gram the recipe is
  /// written to.
  func beakerA(forTapFraction target: Double) -> Double {
    var low = 0.0
    var high = 10 * kettleFill.total + 1000
    for _ in 0 ..< 200 {
      let middle = (low + high) / 2
      var probe = self
      probe.kettleFill.demineralized = middle
      if probe.delivered.tapFraction > target {
        low = middle
      } else {
        high = middle
      }
    }
    return (low + high) / 2
  }
}
