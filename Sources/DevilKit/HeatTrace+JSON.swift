public extension HeatTrace {
  /// The array that goes in the brew's sidecar, beside `samples`.
  ///
  /// ```json
  /// [[12.4, 78.1, 79.0, 79.2, 80.1, 80.4, 24.9], ...]
  /// ```
  ///
  /// Seconds, then the zones in order, then the handle. Hand-rolled like
  /// `PourTrace`'s, because `DevilKit` has no Foundation and so no encoder.
  ///
  /// Seconds to two decimals and degrees to one. The probe reports tenths, so
  /// a second decimal on a temperature would be invented precision.
  var samplesJSON: String {
    let rows = samples.map { sample in
      // Seconds and rounding borrowed from `PourTrace`, so both series in a
      // sidecar place their readings on the same clock the same way.
      let parts = [PourTrace.rounded(sample.seconds, places: PourTrace.secondsPlaces)]
        + sample.zones.map { PourTrace.rounded($0, places: 1) }
        + [PourTrace.rounded(sample.ambient, places: 1)]
      return "[\(parts.joined(separator: ", "))]"
    }
    return "[\(rows.joined(separator: ", "))]"
  }

  /// Reads one back. The sidecar is written and not read today, but a series
  /// nothing can parse is a series nobody can check.
  static func parse(json: String) -> HeatTrace? {
    var trace = HeatTrace()
    var numbers: [Double] = []
    var current = ""
    var depth = 0

    func flush() {
      if !current.isEmpty, let value = Double(current) {
        numbers.append(value)
      }
      current = ""
    }

    for character in json {
      switch character {
      case "[":
        depth += 1
        if depth == 2 {
          numbers = []
        }
      case "]":
        flush()
        if depth == 2 {
          guard numbers.count >= 3 else { return nil }
          trace.append(
            seconds: numbers[0],
            zones: Array(numbers[1 ..< (numbers.count - 1)]),
            ambient: numbers[numbers.count - 1]
          )
        }
        depth -= 1
      case ",":
        flush()
      case " ", "\n", "\t", "\r":
        continue
      default:
        current.append(character)
      }
    }
    return depth == 0 ? trace : nil
  }
}

public extension HeatTrace {
  /// Pulls the `temperatures` array out of a whole sidecar.
  ///
  /// The file holds two series and `PourTrace` reads the other one, so each
  /// finds its own rather than either parsing a document it does not own.
  static func body(in json: String) -> String? {
    let key = "\"temperatures\":"
    guard let start = json.range(of: key) else { return nil }
    var depth = 0
    var body = ""
    for character in json[start.upperBound...] {
      if character == "[" {
        depth += 1
      }
      if depth > 0 {
        body.append(character)
      }
      if character == "]" {
        depth -= 1
        if depth == 0 {
          return body
        }
      }
    }
    return nil
  }
}
