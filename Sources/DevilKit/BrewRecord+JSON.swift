public extension BrewRecord {
  /// The sidecar that goes to disk beside the markdown.
  ///
  /// The readings, and the facts about the brew that produced them, so the
  /// file explains itself to whatever reads it next.
  ///
  /// The file does not name its own brew: it is called after the minute the
  /// brew started, so a `brew` field inside would be the filename written
  /// twice. Nor does it say whether the brew finished, which is a fact about
  /// the brew rather than about the readings.
  ///
  /// The facts are a copy. The markdown holds the same numbers and stays the
  /// record: it is the one you edit, and the one the app reads back. Nothing
  /// here is read back, so the two cannot drift apart through this file. Edit
  /// a fact by hand here and the app will not notice, which is the price of
  /// having the sidecar stand alone.
  ///
  /// `samples` goes last on purpose. It is thousands of times longer than
  /// everything above it, and a reader opening the file should see what the
  /// brew was before the wall of numbers.
  func json(trace: PourTrace) -> String {
    var fields: [String] = []
    fields.append(Self.field("brewed", stamp.timestamp))
    fields.append(Self.field("recipe", recipe))
    fields.append("\"servings\": \(servings)")
    fields.append("\"dose\": \(Format.number(dose))")
    fields.append("\"water\": \(Format.number(water))")
    fields.append(Self.field("grind", grind))
    fields.append("\"grindMicrons\": \(Int(grindMicrons.rounded()))")
    fields.append(Self.field("grinder", grinder))
    fields.append(Self.field("filter", filter))
    fields.append("\"brewTemperature\": \(Format.number(brewTemperature))")
    fields.append("\"temperatureTarget\": \(Format.number(temperatureTarget))")
    fields.append("\"roomTemperature\": \(Format.number(roomTemperature))")
    fields.append("\"beakerA\": \(Format.number(beakerA))")
    fields.append("\"beakerB\": \(Format.number(beakerB))")
    if let vessel {
      fields.append(Self.field("vessel", vessel))
    }
    if let drink {
      fields.append("\"drink\": \(Format.number(drink))")
    }
    fields.append("\"samples\": \(trace.samplesJSON)")
    return "{\(fields.joined(separator: ", "))}"
  }

  /// A quoted field, with the two characters JSON will not take raw.
  private static func field(_ name: String, _ value: String) -> String {
    var escaped = ""
    for character in value {
      switch character {
      case "\\": escaped += "\\\\"
      case "\"": escaped += "\\\""
      default: escaped.append(character)
      }
    }
    return "\"\(name)\": \"\(escaped)\""
  }
}
