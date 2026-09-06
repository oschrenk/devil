/// A clock that can be held.
///
/// Not a running object, and not a `Date`: it is told the raw seconds since the
/// brew's nominal 0:00 and answers what the brew's own clock reads. Nothing
/// ticks inside it, so a test can walk a whole brew, holds and all, without
/// waiting for one.
///
/// Raw seconds are negative during the lead-in, which is what makes a hold
/// during the countdown work without a special case: 0:00 simply arrives later
/// by exactly the time held.
public struct BrewClock: Equatable, Sendable {
  /// Seconds spent held, across every hold so far.
  public private(set) var heldTotal: Double
  /// The raw second-count at which the current hold began, or `nil` if running.
  public private(set) var heldAt: Double?

  public init() {
    heldTotal = 0
    heldAt = nil
  }

  public var isHeld: Bool {
    heldAt != nil
  }

  /// What the brew's clock reads, given the raw seconds since its nominal 0:00.
  ///
  /// While held this is frozen at the moment the hold began, so the display
  /// stops rather than jumping when it resumes.
  public func elapsed(raw: Double) -> Double {
    (heldAt ?? raw) - heldTotal
  }

  /// Hold the clock. Holding an already-held clock does nothing, so a repeated
  /// tap cannot lose the moment the first one recorded.
  public mutating func hold(raw: Double) {
    guard heldAt == nil else { return }
    heldAt = raw
  }

  /// Let the clock go, adding however long it was held to the running total.
  public mutating func release(raw: Double) {
    guard let heldAt else { return }
    heldTotal += max(0, raw - heldAt)
    self.heldAt = nil
  }
}
