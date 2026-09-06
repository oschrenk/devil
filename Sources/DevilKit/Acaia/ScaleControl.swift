/// What a scale event does to the brew on the phone.
public enum ScaleReaction: Equatable, Sendable {
  case holdTheClock
  case doNothing
}

/// The scale-to-phone half of the sync, as a rule rather than as a callback.
///
/// Here so it can be asserted. The case that matters most is the absent one:
/// a scale carried out of range reports no press at all, and a brew must not
/// end because Bluetooth did.
public enum ScaleControl {
  /// `button` is the last press the scale reported, or `nil` when it has
  /// reported none, which includes having gone away.
  public static func reaction(to button: AcaiaButton?, clockIsHeld: Bool) -> ScaleReaction {
    guard let button, !clockIsHeld else { return .doNothing }
    switch button {
    case .stop:
      return .holdTheClock
    // A reset zeroes the scale's own timer. Mid-brew that is a fumble more
    // often than an intention, and the scale reports it separately from a
    // stop, so only the deliberate one stops the brew.
    case .reset, .start, .tare:
      return .doNothing
    }
  }
}
