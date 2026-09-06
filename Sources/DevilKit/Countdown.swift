/// The head start before 0:00.
///
/// A brew begins the moment water touches coffee, so the clock has to be
/// running before you pour. The lead-in is the gap between pressing start and
/// that moment, spent getting the kettle over the bed.
public enum Countdown {
  public static let leadIn = 3

  /// What to show on the clock, given how long is left until the brew starts.
  ///
  /// Counts whole seconds down, so 3 holds for a full second before 2 appears,
  /// and 0 means the brew has begun. A gap that has already passed reads 0
  /// rather than a negative.
  public static func remaining(untilStart interval: Double) -> Int {
    interval <= 0 ? 0 : Int(interval.rounded(.up))
  }
}
