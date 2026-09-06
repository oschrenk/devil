import DevilKit
import Foundation

extension BrewStamp {
  /// The phone's clock, taken apart for `DevilKit`.
  ///
  /// The offset comes from the phone rather than a guess, so a brew read back
  /// anywhere reports the hour it happened.
  init(_ date: Date, calendar: Calendar = .current, timeZone: TimeZone = .current) {
    let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
    self.init(
      year: parts.year ?? 0,
      month: parts.month ?? 0,
      day: parts.day ?? 0,
      hour: parts.hour ?? 0,
      minute: parts.minute ?? 0,
      utcOffsetMinutes: timeZone.secondsFromGMT(for: date) / 60
    )
  }
}

/// Where the brews live.
///
/// One `URL` decides that, which is the whole of the iCloud move later. The
/// files are the store, so nothing here caches or indexes them.
struct BrewLogStore {
  let folder: URL

  init(folder: URL? = nil) {
    self.folder = folder ?? URL.documentsDirectory.appending(path: "Brews")
  }

  func markdown(for stem: String) -> URL {
    folder.appending(path: "\(stem).md")
  }

  func trace(for stem: String) -> URL {
    folder.appending(path: "\(stem).json")
  }

  /// The file exactly as it sits on disk.
  func text(for record: BrewRecord) -> String? {
    try? String(contentsOf: markdown(for: record.stamp.stem), encoding: .utf8)
  }

  /// Writes notes into the existing file rather than rendering a new one, so
  /// anything you added in Obsidian is still there afterwards.
  func save(_ notes: String, for record: BrewRecord) {
    guard let text = text(for: record) else { return }
    let edited = BrewRecord.apply(notes, to: text)
    try? edited.write(to: markdown(for: record.stamp.stem), atomically: true, encoding: .utf8)
  }

  /// The pour, or `nil` for a brew made without a scale.
  func pour(for record: BrewRecord) -> PourTrace? {
    guard record.trace != nil,
          let text = try? String(contentsOf: trace(for: record.stamp.stem), encoding: .utf8)
    else { return nil }
    return PourTrace.parse(json: text)?.trace
  }

  /// What a share sheet hands over.
  ///
  /// The sidecar joins only when it is on disk. A brew made without a scale
  /// has none, and offering a file that is not there fails at the moment the
  /// sheet opens, which is the worst moment to find out.
  func files(for record: BrewRecord) -> [URL] {
    let stem = record.stamp.stem
    var files = [markdown(for: stem)]
    if FileManager.default.fileExists(atPath: trace(for: stem).path()) {
      files.append(trace(for: stem))
    }
    return files
  }

  /// Every brew on disk, newest first.
  ///
  /// Read each time rather than cached. The files are the store, so a brew
  /// edited in another app is the brew this returns.
  ///
  /// Sorting by stem is sorting by time. The name is zero-padded from year
  /// down to minute, so its alphabetical order is its chronological one, and
  /// no date has to be parsed to put the list in order.
  func brews() -> [BrewRecord] {
    let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path())) ?? []
    return names
      .filter { $0.hasSuffix(".md") }
      .compactMap { name -> BrewRecord? in
        let text = try? String(contentsOf: folder.appending(path: name), encoding: .utf8)
        return text.flatMap(BrewRecord.parse(markdown:))
      }
      .sorted { $0.stamp.stem > $1.stamp.stem }
  }

  /// Removes a brew and its sidecar. A missing sidecar is not a failure.
  func delete(_ record: BrewRecord) {
    let stem = record.stamp.stem
    try? FileManager.default.removeItem(at: markdown(for: stem))
    try? FileManager.default.removeItem(at: trace(for: stem))
  }

  /// Writes the pair, and returns the stem they share.
  ///
  /// A brew with no readings writes no sidecar. An empty `samples` array on
  /// disk claims a scale was watching and saw nothing, which is a different
  /// morning from one brewed without a scale.
  @discardableResult
  func save(_ record: BrewRecord, trace pour: PourTrace?) -> String? {
    var record = record
    let stem = record.stamp.stem
    let hasReadings = (pour?.samples.isEmpty == false)
    record.trace = hasReadings ? "\(stem).json" : nil

    do {
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
      try record.markdown.write(to: markdown(for: stem), atomically: true, encoding: .utf8)
      if hasReadings, let pour {
        try pour.json(brew: stem).write(to: trace(for: stem), atomically: true, encoding: .utf8)
      }
      return stem
    } catch {
      // A brew that cannot be written is not a brew that should be lost in
      // silence, and the console is the only place to say so today.
      print("[Devil] could not write brew \(stem): \(error)")
      return nil
    }
  }
}
