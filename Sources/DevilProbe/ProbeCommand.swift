import DevilKit
import Foundation
import libzstd

/// What Devil says to a ThermoMaven.
///
/// The base station streams because something asks it to. The vendor's app
/// sends `BT:apply:trust` on connect and then its requests; Devil only ever
/// listened, so nothing arrived unless that app was there doing the asking.
///
/// Read-only commands only. The vocabulary in their app also holds
/// `BT:Config:WIFI`, `BT:Probe:Unpair` and `device:user:unbind`, and one of
/// those can unpair a probe from an account. None of them belong here.
public enum ProbeCommand: String, Sendable, CaseIterable {
  /// Sent first, and the base station replies with a receipt. Whether it
  /// checks an identity from the vendor's cloud is the open question in
  /// `DEVIL-47`, and only sending one answers it.
  case applyTrust = "BT:apply:trust"
  /// The status reports `DEVIL-46` decodes.
  case statusRequest = "device:status:request"
  case probeRequest = "BT:Probe:Request"

  /// The JSON body, with the fields `BtSendCmd` carries.
  ///
  /// `cmdId` is a bare hexadecimal string in every captured report, and the
  /// sequence number is a string rather than a number, which is theirs rather
  /// than a mistake here.
  ///
  /// `BT:apply:trust` needs an account. The device volunteers one in every
  /// receipt it sends, so Devil learns it rather than being told it: send
  /// anything, read the `userId` off the refusal, and apply trust with it.
  public func json(id: String, sequence: Int, userId: String? = nil) -> String {
    """
    {"cmdType":"\(rawValue)","cmdId":"\(id)","cmdSeqNo":"\(sequence)",\
    "protocol":"BT","cmdData":\(data(userId: userId))}
    """
  }

  /// Trust carries six fields, and the rest carry none.
  ///
  /// The units are display preferences and the wire stays Fahrenheit either
  /// way, but the field is not optional. `direct` rather than `pair`, because
  /// this is a probe already paired to the base station.
  private func data(userId: String?) -> String {
    guard self == .applyTrust else { return "{}" }
    return """
    {"userId":"\(userId ?? "")","deviceModel":"WT11","mode":"direct",\
    "temperatureUnit":"C","lengthUnit":"cm","weightUnit":"g"}
    """
  }

  /// The BluFi frames to write, ready for `ff01`.
  ///
  /// `nil` when compression fails, which would mean a broken zstd rather than
  /// a bad command, and sending half a message is worse than sending none.
  public func frames(
    id: String,
    sequence: Int,
    from frame: UInt8,
    userId: String? = nil
  ) -> [[UInt8]]? {
    let raw = Array(json(id: id, sequence: sequence, userId: userId).utf8)
    guard let body = Zstd.compress(raw) else { return nil }
    let message = BtProtocolPackage.wrap(body: body, expanding: raw)
    return BlufiWriter.frames(for: message, startingAt: frame)
  }

  /// Sixteen hexadecimal characters, the shape of the ids in their reports.
  public static func newID() -> String {
    (0 ..< 32).map { _ in String(format: "%x", Int.random(in: 0 ... 15)) }.joined()
  }
}
