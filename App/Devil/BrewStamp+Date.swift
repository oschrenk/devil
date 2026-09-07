import DevilKit
import Foundation

extension BrewStamp {
  /// The instant this brew started, rebuilt from its parts.
  ///
  /// `DevilKit` holds the parts and no `Foundation`, so the reassembly and
  /// every word of the formatting happen here.
  var date: Date? {
    var parts = DateComponents()
    parts.year = year
    parts.month = month
    parts.day = day
    parts.hour = hour
    parts.minute = minute
    parts.timeZone = TimeZone(secondsFromGMT: utcOffsetMinutes * 60)
    return Calendar(identifier: .gregorian).date(from: parts)
  }

  /// The system's own idea of a date, so it reads the way the rest of the
  /// phone does rather than the way a filename does.
  ///
  /// Shown in the offset the brew was made in, not the one you are standing
  /// in. A brew made at seven in Amsterdam reads as seven wherever it is
  /// read back.
  var readableDay: String {
    guard let date else { return readable }
    var style = Date.FormatStyle.dateTime.weekday(.abbreviated).day().month(.wide).year()
    style.timeZone = recorded
    return date.formatted(style)
  }

  var readableTime: String {
    guard let date else { return "" }
    var style = Date.FormatStyle.dateTime.hour().minute()
    style.timeZone = recorded
    return date.formatted(style)
  }

  private var recorded: TimeZone {
    TimeZone(secondsFromGMT: utcOffsetMinutes * 60) ?? .gmt
  }
}
