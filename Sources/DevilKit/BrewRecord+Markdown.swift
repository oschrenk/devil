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

    var body: [String?] = []
    body.append(Self.field("Beans", notes.beans))
    body.append(Self.field("Recipe", Self.recipeTag))
    // Typed, not filled in. The tap and demineralized split is temperature
    // management rather than a water recipe, and `#water/` names a mineral
    // profile this app knows nothing about. The split stays in frontmatter as
    // `beakerA` and `beakerB`, where it is a measurement and not a claim.
    body.append(Self.field("Water Recipe", notes.waterRecipe))
    body.append(Self.field("Grinder", grinder))
    body.append(Self.field("Grind Size", Format.grind(grind)))
    body.append(Self.field("Total Dissolved Solids", notes.totalDissolvedSolids))
    body.append(Self.field("Temperature", Format.degrees(brewTemperature)))
    body.append(Self.field("Yield", Format.grams(water)))
    body.append(Self.field("Concentration", notes.concentration))
    body.append(Self.field("Aroma", notes.aroma))
    body.append(Self.field("Flavour", notes.flavour))
    body.append(Self.field("Aftertaste", notes.aftertaste))
    body.append(Self.field("Acidity", notes.acidity))
    body.append(Self.field("Sweetness", notes.sweetness))
    body.append(Self.field("Bitterness", notes.bitterness))
    body.append(Self.field("Weight", Format.grams(dose)))
    body.append(Self.field("Texture", notes.texture))
    body.append(Self.field("Afterfeel", notes.afterfeel))
    body.append(Self.field("Balance", notes.balance))
    lines.append(contentsOf: body.compactMap(\.self))
    return lines.joined(separator: "\n") + "\n"
  }

  /// A line, or nothing when there is nothing to say.
  ///
  /// The file states what is known. Nineteen labels with thirteen blanks
  /// after them is a form, and a form nobody can fill in yet is noise in
  /// every brew ever written. A field appears when it has an answer.
  static func field(_ label: String, _ value: String) -> String? {
    value.isEmpty ? nil : "- \(label): \(value)"
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
