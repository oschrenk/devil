public extension BrewRecord {
  /// The file that goes to disk.
  ///
  /// Frontmatter states what the app measured. The body repeats seven of those
  /// values inside the vault's own bullet list, so a brew pastes into a daily
  /// note without being retyped.
  ///
  /// Those seven lines are written and never read back. Frontmatter is the
  /// record, so rewording a line in Obsidian changes what you read there and
  /// leaves what the app measured alone.
  var markdown: String {
    var lines = ["---"]
    lines.append("brewed: \(stamp.timestamp)")
    lines.append("recipe: \(recipe)")
    lines.append("servings: \(servings)")
    lines.append("dose: \(Format.number(dose))")
    lines.append("water: \(Format.number(water))")
    lines.append("grind: \(Format.grind(grind))")
    lines.append("grinder: \(grinder)")
    lines.append("filter: \(filter)")
    lines.append("brewTemperature: \(Format.number(brewTemperature))")
    lines.append("temperatureTarget: \(Format.number(temperatureTarget))")
    lines.append("beakerA: \(Format.number(beakerA))")
    lines.append("beakerB: \(Format.number(beakerB))")
    lines.append("finished: \(finished)")
    if let trace {
      lines.append("trace: \(trace)")
    }
    lines.append("---")
    lines.append("")
    lines.append("# \u{2615}\u{FE0F} \(stamp.readable)")
    lines.append("")

    let waterRecipe = "\(Format.grams(beakerA)) tap, \(Format.grams(beakerB)) demineralized"
    lines.append("- Beans: \(notes.beans)")
    lines.append("- Recipe: \(Self.recipeTag)")
    lines.append("- Water Recipe: \(waterRecipe)")
    lines.append("- Grinder: \(grinder)")
    lines.append("- Grind Size: \(Format.grind(grind))")
    lines.append("- Total Dissolved Solids: \(notes.totalDissolvedSolids)")
    lines.append("- Temperature: \(Format.degrees(brewTemperature))")
    lines.append("- Yield: \(Format.grams(water))")
    lines.append("- Concentration: \(notes.concentration)")
    lines.append("- Aroma: \(notes.aroma)")
    lines.append("- Flavour: \(notes.flavour)")
    lines.append("- Aftertaste: \(notes.aftertaste)")
    lines.append("- Acidity: \(notes.acidity)")
    lines.append("- Sweetness: \(notes.sweetness)")
    lines.append("- Bitterness: \(notes.bitterness)")
    lines.append("- Weight: \(Format.grams(dose))")
    lines.append("- Texture: \(notes.texture)")
    lines.append("- Afterfeel: \(notes.afterfeel)")
    lines.append("- Balance: \(notes.balance)")
    return lines.joined(separator: "\n") + "\n"
  }

  /// The one recipe this app brews, so it needs no field of its own.
  static var recipeTag: String {
    "#recipe/hario-switch"
  }

  /// Reads a file back, and `nil` when the frontmatter will not parse.
  ///
  /// Values come from frontmatter and notes come from the body, so each fact
  /// has one source. A file whose bullet list you reworded still returns the
  /// numbers the app wrote.
  static func parse(markdown: String) -> BrewRecord? {
    let lines = markdown.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    guard lines.first == "---",
          let end = lines.dropFirst().firstIndex(of: "---")
    else { return nil }

    var front: [String: String] = [:]
    for line in lines[1 ..< end] {
      guard let split = line.firstIndex(of: ":") else { continue }
      let key = String(line[line.startIndex ..< split])
      let value = String(line[line.index(after: split)...])
      front[key.trimmed] = value.trimmed
    }

    guard let brewed = front["brewed"], let stamp = BrewStamp.parse(timestamp: brewed),
          let servings = front["servings"].flatMap(Int.init),
          let dose = front["dose"].flatMap(Double.init),
          let water = front["water"].flatMap(Double.init),
          let grind = front["grind"].flatMap(Double.init),
          let filter = front["filter"],
          let brewTemperature = front["brewTemperature"].flatMap(Double.init),
          let temperatureTarget = front["temperatureTarget"].flatMap(Double.init),
          let beakerA = front["beakerA"].flatMap(Double.init),
          let beakerB = front["beakerB"].flatMap(Double.init)
    else { return nil }

    var notes = BrewNotes(beans: "")
    for line in lines[end...] where line.hasPrefix("- ") {
      let body = String(line.dropFirst(2))
      // The first colon only. A tasting note is prose and may hold more.
      guard let split = body.firstIndex(of: ":") else { continue }
      let label = String(body[body.startIndex ..< split]).trimmed
      let value = String(body[body.index(after: split)...]).trimmed
      if let field = BrewNotes.fields.first(where: { $0.label == label }) {
        notes[keyPath: field.key] = value
      }
    }

    return BrewRecord(
      stamp: stamp,
      recipe: front["recipe"] ?? "",
      servings: servings,
      dose: dose,
      water: water,
      grind: grind,
      grinder: front["grinder"] ?? "",
      filter: filter,
      brewTemperature: brewTemperature,
      temperatureTarget: temperatureTarget,
      beakerA: beakerA,
      beakerB: beakerB,
      finished: front["finished"] == "true",
      trace: front["trace"],
      notes: notes
    )
  }
}

extension String {
  var trimmed: String {
    var scalars = Array(self)
    while let first = scalars.first, first == " " || first == "\t" {
      scalars.removeFirst()
    }
    while let last = scalars.last, last == " " || last == "\t" || last == "\r" {
      scalars.removeLast()
    }
    return String(scalars)
  }
}
