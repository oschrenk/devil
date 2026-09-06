/// When a brew happened, held as its parts.
///
/// Parts rather than a `Date`, because `DevilKit` has no `Foundation` and a
/// `DateFormatter` would drag the whole of it in. The app reads the clock and
/// hands the pieces over, which also keeps the tests free of today's date.
public struct BrewStamp: Equatable, Sendable {
  public var year: Int
  public var month: Int
  public var day: Int
  public var hour: Int
  public var minute: Int
  /// Minutes east of UTC, as the phone had it when the brew started.
  ///
  /// Written down rather than assumed. A 07:14 brew stored without an offset
  /// reads back as a different hour anywhere else, and a log of mornings that
  /// disagrees about which morning is worth nothing.
  public var utcOffsetMinutes: Int

  public init(
    year: Int,
    month: Int,
    day: Int,
    hour: Int,
    minute: Int,
    utcOffsetMinutes: Int = 0
  ) {
    self.year = year
    self.month = month
    self.day = day
    self.hour = hour
    self.minute = minute
    self.utcOffsetMinutes = utcOffsetMinutes
  }

  static func padded(_ value: Int, _ width: Int) -> String {
    let digits = String(abs(value))
    let short = width - digits.count
    return short > 0 ? String(repeating: "0", count: short) + digits : digits
  }

  /// `2026-09-06T0714`, which names both files.
  ///
  /// The `T` separates the date from the time, where a second dash reads as
  /// another part of the date. Strict ISO 8601 refuses to mix an extended
  /// date with a basic time, and the strictly correct `20260906T0714` reads
  /// worse and sits badly beside a vault of `2026-09-06` notes.
  ///
  /// No colon, because that is illegal in a filename on Windows and Finder
  /// rewrites it. No space, because every shell that touches these files
  /// would then need quoting. `brewed` in the frontmatter is real ISO 8601,
  /// offset and all, and that is the machine-readable one.
  public var stem: String {
    let date = "\(Self.padded(year, 4))-\(Self.padded(month, 2))-\(Self.padded(day, 2))"
    return "\(date)T\(Self.padded(hour, 2))\(Self.padded(minute, 2))"
  }

  /// `2026-09-06 07:14`, for the heading.
  public var readable: String {
    let date = "\(Self.padded(year, 4))-\(Self.padded(month, 2))-\(Self.padded(day, 2))"
    return "\(date) \(Self.padded(hour, 2)):\(Self.padded(minute, 2))"
  }

  /// `2026-09-06T07:14:00+02:00`.
  public var timestamp: String {
    let date = "\(Self.padded(year, 4))-\(Self.padded(month, 2))-\(Self.padded(day, 2))"
    let time = "\(Self.padded(hour, 2)):\(Self.padded(minute, 2)):00"
    if utcOffsetMinutes == 0 {
      return "\(date)T\(time)Z"
    }
    let sign = utcOffsetMinutes < 0 ? "-" : "+"
    let total = abs(utcOffsetMinutes)
    return "\(date)T\(time)\(sign)\(Self.padded(total / 60, 2)):\(Self.padded(total % 60, 2))"
  }

  /// Reads back what `timestamp` wrote, and `nil` for anything else.
  public static func parse(timestamp: String) -> BrewStamp? {
    let scalars = Array(timestamp)
    guard scalars.count >= 20, scalars[10] == "T" else { return nil }
    func number(_ from: Int, _ count: Int) -> Int? {
      Int(String(scalars[from ..< from + count]))
    }
    guard let year = number(0, 4), let month = number(5, 2), let day = number(8, 2),
          let hour = number(11, 2), let minute = number(14, 2)
    else { return nil }

    var offset = 0
    if scalars[19] != "Z" {
      guard scalars.count >= 25, let hours = number(20, 2), let minutes = number(23, 2)
      else { return nil }
      offset = hours * 60 + minutes
      if scalars[19] == "-" {
        offset = -offset
      }
    }
    return BrewStamp(
      year: year, month: month, day: day,
      hour: hour, minute: minute, utcOffsetMinutes: offset
    )
  }
}
