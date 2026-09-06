/// Works out whether the scale's timer is running, from its time alone.
///
/// This scale reports no key events. Pressing tare, start or stop on it sends
/// nothing the app can see, which is confirmed rather than assumed: the
/// subscription matches both published implementations byte for byte, and a
/// capture over 75 seconds held weight, timer and settings and not one press.
///
/// What it does report is its time, every couple of seconds and again the
/// moment the button is pressed. A time that repeats is a clock that has
/// stopped, and that is enough to follow it.
public struct ScaleTimerWatch: Equatable, Sendable {
  private var last: Double?

  /// `nil` until two readings have arrived, because one number says nothing
  /// about whether it is moving.
  public private(set) var isRunning: Bool?

  public init() {}

  /// A clock stopped somewhere other than zero.
  ///
  /// The distinction matters at the start of a brew. A scale sitting idle
  /// reports zero over and over, which is a stopped clock but not a paused
  /// brew, and acting on it would hold the timer the moment it began.
  public var hasPaused: Bool {
    isRunning == false && (last ?? 0) > 0
  }

  /// Take a reading. Returns `true` when this one changed the answer, which is
  /// the moment worth acting on.
  @discardableResult
  public mutating func observe(seconds: Double) -> Bool {
    defer { last = seconds }
    guard let last else { return false }

    let wasRunning = isRunning
    if seconds > last {
      isRunning = true
    } else {
      // Equal means stopped. Lower means someone reset it, which is also not
      // running. Neither needs a second opinion.
      isRunning = false
    }
    return isRunning != wasRunning
  }
}
