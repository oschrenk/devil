/// Everything the app ever sends the scale.
///
/// Seven messages, and only two of them are optional. Without `identify` and
/// `subscribe` the scale accepts the connection and then says nothing at all,
/// and without `heartbeat` every few seconds it drops the link.
public enum AcaiaCommand: Equatable, Sendable, CaseIterable {
  case tare
  case startTimer
  case stopTimer
  case resetTimer
  case heartbeat
  /// Announces the app to the scale. The payload is fifteen ASCII digits for
  /// the newer scales, which is what a Pearl S is.
  case identify
  /// Asks for weight, battery, timer and button events. The pairs are register
  /// and value; the timer's value is how many heartbeats pass between timer
  /// messages, which is why the scale's clock arrives slowly.
  case subscribe

  var type: UInt8 {
    switch self {
    case .heartbeat: 0
    case .tare: 4
    case .identify: 11
    case .subscribe: 12
    case .startTimer, .stopTimer, .resetTimer: 13
    }
  }

  var payload: [UInt8] {
    switch self {
    case .tare: [0]
    case .startTimer: [0, 0]
    case .resetTimer: [0, 1]
    case .stopTimer: [0, 2]
    case .heartbeat: [2, 0]
    case .identify: Array("012345678901234".utf8)
    case .subscribe: [9, 0, 1, 1, 2, 2, 5, 3, 4]
    }
  }

  public var bytes: [UInt8] {
    AcaiaFrame.command(type, payload)
  }
}
