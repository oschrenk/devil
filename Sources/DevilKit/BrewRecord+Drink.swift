public extension BrewRecord {
  /// Writes the vessel and the drink weight into a file that already exists.
  ///
  /// Surgical, for the reason `apply(_:to:)` is: the bullets are what the app
  /// measured and the tail below them is yours, so re-rendering the record
  /// would overwrite a note to change a number above it.
  ///
  /// A brew is weighed once, but the vessel can be picked wrong, so a second
  /// pass replaces the first rather than writing the key twice.
  static func applyDrink(vessel: String?, drink: Double?, to markdown: String) -> String {
    var lines = markdown.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    guard lines.first == "---", let end = lines.dropFirst().firstIndex(of: "---")
    else { return markdown }

    var front = lines[1 ..< end].filter {
      !$0.hasPrefix("vessel:") && !$0.hasPrefix("drink:")
    }
    if let vessel {
      front.append("vessel: \(vessel)")
    }
    if let drink {
      front.append("drink: \(Format.number(drink))")
    }
    lines.replaceSubrange(1 ..< end, with: front)
    return lines.joined(separator: "\n")
  }
}
