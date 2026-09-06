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
