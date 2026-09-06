/// Decides when to tell the scale a brew has begun.
///
/// A brew screen redraws every second, so "send it at 0:00" needs a memory or
/// it sends every tick from then on. Keeping that memory here, rather than in
/// the view, means the rule is testable without a scale and without waiting
/// three seconds for a countdown.
public struct BrewStartSignal: Equatable, Sendable {
  private var sent = false

  public init() {}

  public var hasSent: Bool {
    sent
  }

  /// What to send the scale, given the brew clock. Empty on every call but the
  /// first one at or past 0:00.
  ///
  /// Only a start. The reset belongs at the moment the button is pressed, three
  /// seconds earlier: sending both here makes the scale beep twice at 0:00,
  /// which is the one moment a single unambiguous beep is worth having.
  public mutating func commands(elapsed: Double) -> [AcaiaCommand] {
    guard !sent, elapsed >= 0 else { return [] }
    sent = true
    return [.startTimer]
  }
}
