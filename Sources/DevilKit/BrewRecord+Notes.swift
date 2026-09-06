public extension BrewRecord {
  /// Writes a note into a file that already exists, and changes nothing above
  /// it.
  ///
  /// Rendering the record afresh would be shorter and wrong. The frontmatter
  /// and the bullets are what the app measured, and re-deriving them lets a
  /// change to `Scaling` rewrite last week.
  ///
  /// Everything after the last bullet is the note, so a heading you added in
  /// Obsidian reads back into the editor and goes out again as you left it.
  static func apply(_ notes: String, to markdown: String) -> String {
    var lines = markdown.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    guard let last = lines.lastIndex(where: { $0.hasPrefix("- ") }) else { return markdown }

    lines.removeSubrange((last + 1)...)
    if !notes.isEmpty {
      lines.append("")
      lines.append(notes)
    }
    return lines.joined(separator: "\n") + "\n"
  }
}
