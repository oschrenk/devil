import ActivityKit
import Foundation

/// What the Lock Screen shows while a brew runs.
///
/// Compiled into the app and into the widget extension, because both sides
/// have to agree on the shape and neither can import the other.
struct BrewAttributes: ActivityAttributes, Sendable {
  /// The part that changes as the brew goes on.
  ///
  /// The clock is not in here. `Text(timerInterval:)` counts on its own from
  /// the dates below, so the system animates it and the app sends nothing.
  /// Putting seconds in the state would mean an update a second, which
  /// ActivityKit throttles and the battery would notice.
  struct ContentState: Codable, Hashable, Sendable {
    var stepTitle: String
    var instruction: String
    var switchIsOpen: Bool
    /// Where the clock stopped, when it is stopped.
    ///
    /// A running clock is drawn from the dates and needs nothing here. A held
    /// one cannot be, because the dates keep moving and the clock does not.
    var heldAtSeconds: Double?
  }

  /// When the brew clock reached 0:00.
  var start: Date
  /// When the recipe ends, which bounds the timer the widget draws.
  var finish: Date
  var servings: Int
}
