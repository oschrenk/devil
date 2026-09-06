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

  /// When the last drips land, or `nil` at a size nobody has timed.
  ///
  /// Not the same as `totalTime`, which is only where the schedule stops. With
  /// no observed finish the schedule stops at the drain, and a screen should
  /// show that there is no answer rather than showing 2:30 as if there were.
  var finish: BrewTime? {
    steps.first { $0.actions.contains(.finish) }?.start
  }

  /// How long a step lasts, in seconds, or `nil` for the last one, which marks
  /// the end of the brew rather than a wait.
  func duration(of step: Step) -> Int? {
    guard let next = steps.first(where: { $0.start > step.start }) else { return nil }
    return next.start.seconds - step.start.seconds
  }

  /// The step times that can be labelled on an axis without colliding.
  ///
  /// Every step is worth a mark, but not every one is worth a name: the swirl
  /// at 0:10 sits ten seconds after the first pour, and on a phone the two
  /// labels overlap into an unreadable smear. Dropping the ones too close to
  /// the last kept label keeps the times that are actually recipe landmarks.
  func labelledStepTimes(minimumGap: Int) -> [Int] {
    var kept: [Int] = []
    for step in steps.sorted(by: { $0.start < $1.start }) {
      if let last = kept.last, step.start.seconds - last < minimumGap {
        continue
      }
      kept.append(step.start.seconds)
    }
    return kept
  }

  /// How much water has gone through the bed by the end of a step.
  ///
  /// The figure a scale should read at that point, given the server was tared
  /// empty. A step that pours nothing inherits the total before it, so a swirl
  /// or a drain names the number the previous pour reached rather than a new
  /// one, which is what makes it usable as a target throughout.
  func cumulativeTarget(through step: Step) -> Double {
    steps
      .sorted { $0.start < $1.start }
      .prefix { $0.start <= step.start }
      .reduce(0) { $0 + $1.poured }
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

  /// What the kettle holds when the cooler goes in, before it goes in.
  var kettleBeforeCooler: Double {
    guard let coolerStep = steps.first(where: { $0.coolerAdded > 0 }) else {
      return kettleFill.total
    }
    let pouredBefore = steps
      .filter { $0.start < coolerStep.start }
      .reduce(0) { $0 + $1.poured }
    return kettleFill.total - pouredBefore
  }

  /// The kettle temperature once the cooler goes in, by weighted average.
  ///
  /// Measured against `kettleTemperatureAtLastPour`, not `brewTemperature`.
  /// The kettle has been cooling since the first pour, and using the set
  /// temperature here would call for more cold water than the pour can take.
  var kettleTemperatureAfterCooler: Double {
    let inKettle = kettleBeforeCooler
    let added = steps.reduce(0) { $0 + $1.coolerAdded }
    guard inKettle + added > 0 else { return kettleTemperatureAtLastPour }
    let heat = inKettle * kettleTemperatureAtLastPour + added * cooler.temperature
    return heat / (inKettle + added)
  }

  /// How much cold water the last pour needs to reach `target`.
  ///
  /// This is the other half of `beakerA(forTapFraction:)`: Beaker A sets the
  /// blend, Beaker B sets the temperature, and the recipe is the pair that
  /// satisfies both at once.
  func cooler(forTemperature target: Double) -> Double {
    let inKettle = kettleBeforeCooler
    let hot = kettleTemperatureAtLastPour
    guard hot > target, target > cooler.temperature else { return 0 }
    return inKettle * (hot - target) / (target - cooler.temperature)
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
