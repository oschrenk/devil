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

  /// The envelope, as `BtSendCmd` builds it in their own app.
  ///
  /// Four things were wrong in the first attempt, and the device answered all
  /// of them with the same `cmdError: 6`.
  ///
  /// `cmdSeqNo` is a number here and a string in what the device sends back,
  /// which is theirs rather than a mistake. `serverTime` is milliseconds and
  /// `serverTimeSecond` is seconds, and both go in. `protocol` is null in
  /// their builder, so it is absent rather than empty. And `deviceType` names
  /// the model.
  public func json(
    id: String,
    sequence: Int,
    userId: String? = nil,
    milliseconds: Int,
    deviceId: String = ""
  ) -> String {
    """
    {"cmdId":"\(id)","cmdSeqNo":\(sequence),"cmdType":"\(rawValue)",\
    "serverTime":\(milliseconds),"serverTimeSecond":\(milliseconds / 1000),\
    "deviceId":"\(deviceId)","deviceType":"\(Self.deviceType)",\
    "cmdData":\(data(userId: userId))}
    """
  }

  /// The model, which is what a P1 reports itself as.
  public static let deviceType = "WT11"

  /// Trust carries six fields, and the rest carry none.
  ///
  /// The units are display preferences and the wire stays Fahrenheit either
  /// way, but the field is not optional. `direct` rather than `pair`, because
  /// the probe is already paired to the base station.
  private func data(userId: String?) -> String {
    guard self == .applyTrust else { return "{}" }
    return """
    {"userId":"\(userId ?? "")","deviceModel":"\(Self.deviceType)","mode":"direct",\
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
    userId: String? = nil,
    milliseconds: Int = Int(Date.now.timeIntervalSince1970 * 1000)
  ) -> [[UInt8]]? {
    let raw = Array(
      json(id: id, sequence: sequence, userId: userId, milliseconds: milliseconds).utf8
    )
    guard let body = Zstd.compress(raw) else { return nil }
    let message = BtProtocolPackage.wrap(body: body, expanding: raw)
    return BlufiWriter.frames(for: message, startingAt: frame)
  }

  /// Sixteen hexadecimal characters, the shape of the ids in their reports.
  public static func newID() -> String {
    (0 ..< 32).map { _ in String(format: "%x", Int.random(in: 0 ... 15)) }.joined()
  }
}
