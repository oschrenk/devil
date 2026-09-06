public extension PourTrace {
  /// The sidecar that goes to disk beside the markdown.
  ///
  /// Pairs rather than objects. An object per reading spends twenty-five bytes
  /// on four bytes of fact, and a brew is two thousand readings.
  ///
  /// The file names the brew it belongs to and copies nothing else from the
  /// markdown. A `grind` repeated here could disagree with the one over there,
  /// and then neither file is the record.
  func json(brew: String) -> String {
    let pairs = samples.map {
      "[\(Self.rounded($0.seconds, places: Self.secondsPlaces)), \(Format.number($0.grams))]"
    }
    return "{\"brew\": \"\(brew)\", \"samples\": [\(pairs.joined(separator: ", "))]}"
  }

  /// Hundredths of a second. The scale reports about ten times a second, so
  /// this separates readings a hundred milliseconds apart ten times over.
  ///
  /// One decimal was the first attempt and was wrong: two readings inside the
  /// same tenth collapse to one instant, and `append` drops the second as a
  /// reading that went backwards. Full precision is the other extreme, where
  /// a clock difference prints as `0.30000000000000004` and doubles the file.
  static var secondsPlaces: Int {
    2
  }

  static func rounded(_ value: Double, places: Int) -> String {
    var scale = 1.0
    for _ in 0 ..< places {
      scale *= 10
    }
    let rounded = (value * scale).rounded() / scale
    if rounded == rounded.rounded() {
      return "\(Int(rounded))"
    }
    return "\(rounded)"
  }

  /// Reads a sidecar back, and `nil` for anything that is not one.
  ///
  /// Hand-written rather than `JSONDecoder`, because `DevilKit` has no
  /// `Foundation`. It accepts the shape `json(brew:)` writes and refuses the
  /// rest rather than guessing at it.
  static func parse(json: String) -> (brew: String, trace: PourTrace)? {
    guard let brew = string(named: "brew", in: json),
          let body = samplesBody(in: json),
          let trace = trace(from: body)
    else { return nil }
    return (brew, trace)
  }

  /// What sits between the brackets of the `samples` array.
  private static func samplesBody(in json: String) -> Substring? {
    guard let label = json.range(of: "\"samples\""),
          let start = json[label.upperBound...].firstIndex(of: "["),
          let end = json.lastIndex(of: "]"),
          start < end
    else { return nil }
    return json[json.index(after: start) ..< end]
  }

  /// Each pair ends at its own `]`, so the readings cut themselves apart and
  /// nothing here has to track how deep the brackets went.
  private static func trace(from body: Substring) -> PourTrace? {
    var trace = PourTrace()
    for chunk in body.split(separator: "]") {
      guard let open = chunk.firstIndex(of: "[") else {
        // Whatever separated the last pair from this one, newlines included.
        guard chunk.allSatisfy({ $0 == "," || $0.isWhitespace }) else { return nil }
        continue
      }
      let numbers = chunk[chunk.index(after: open)...].split(separator: ",")
      guard numbers.count == 2,
            let seconds = Double(String(numbers[0]).trimmed),
            let grams = Double(String(numbers[1]).trimmed)
      else { return nil }
      trace.append(seconds: seconds, grams: grams)
    }
    return trace
  }

  private static func string(named key: String, in json: String) -> String? {
    guard let label = json.range(of: "\"\(key)\""),
          let colon = json[label.upperBound...].firstIndex(of: ":"),
          let open = json[json.index(after: colon)...].firstIndex(of: "\""),
          let close = json[json.index(after: open)...].firstIndex(of: "\"")
    else { return nil }
    return String(json[json.index(after: open) ..< close])
  }
}

extension String {
  /// `Foundation` has one of these. `DevilKit` may not import it.
  func range(of needle: String) -> Range<String.Index>? {
    guard !needle.isEmpty else { return nil }
    var from = startIndex
    while let first = self[from...].firstIndex(of: needle.first!) {
      if self[first...].hasPrefix(needle) {
        return first ..< index(first, offsetBy: needle.count)
      }
      guard first < endIndex else { break }
      from = index(after: first)
    }
    return nil
  }
}
