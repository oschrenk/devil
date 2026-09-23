import DevilKit
import Foundation

/// A status report from a ThermoMaven base station.
///
/// Every temperature is tenths of a degree Fahrenheit, which is the one thing
/// about this protocol that is easy to get wrong. The vendor's own app
/// converts for display, and a target of `1580` reads as 70 degrees Celsius
/// on its screen.
public struct ProbeReport: Decodable, Sendable {
  public var cmdType: String
  public var cmdData: Body
  /// The account the base station thinks it belongs to.
  ///
  /// It volunteers this in every receipt, including the ones refusing a
  /// command. That is how Devil learns the id that `BT:apply:trust` wants,
  /// rather than being told it.
  public var userId: String?

  public struct Body: Decodable, Sendable {
    /// The base station's own battery, as a percentage.
    public var batteryValue: Int?
    public var wifiRssi: Int?
    /// Absent on a receipt, which carries an outcome rather than readings.
    public var probes: [Probe]?
    /// `success` or `failure`, on a receipt.
    public var executeResult: String?
    public var cmdError: Int?
    /// Which command this receipt answers.
    public var cmdType: String?
  }

  public var isReceipt: Bool {
    cmdType == "device:cmd:receipt"
  }

  public var refused: Bool {
    cmdData.executeResult == "failure"
  }

  public struct Probe: Decodable, Sendable {
    public var deviceSn: String?
    public var probeColor: String?
    public var cookingState: String?
    /// The probe's battery, which is not the base station's.
    public var batteryValue: Int?
    /// The coldest of the five zones, computed by the device rather than
    /// measured. It equalled `min(areaTemperature)` in all 123 readings of the
    /// 2026-09-22 capture and the first zone in only 58 of them.
    ///
    /// The vendor's app shows this as `Meat`, because the coldest point is
    /// what decides whether meat is done. It is the wrong number for coffee,
    /// and `areaTemperature` holds the measured ones.
    public var curTemperature: Int
    /// Five sensors along the shaft, tip first. These are measured.
    public var areaTemperature: [Int]
    /// The sensor on the handle, out of whatever the tip is in.
    public var curAmbientTemperature: Int
    public var curCookSec: Int?
    public var totalCookSec: Int?
  }

  /// A whole reassembled message, from the `aa aa` to the last checksum.
  ///
  /// `nil` when it does not parse, does not expand to the length it claims, or
  /// is not JSON. No partial answers: a report either survives all three
  /// layers or it is not a report.
  public static func decode(message: [UInt8]) -> ProbeReport? {
    guard let package = BtProtocolPackage.parse(message),
          let json = Zstd.decompress(package.body, expecting: package.expandedCount)
    else { return nil }
    // Every message decodes, receipts included. Requiring readings meant a
    // refusal threw and looked exactly like silence, which cost an evening.
    return try? JSONDecoder().decode(ProbeReport.self, from: Data(json))
  }
}

public extension ProbeReport.Probe {
  /// The coldest of the five, as the device computes it. What the vendor's app
  /// calls `Meat`.
  var coldestCelsius: Double {
    ProbeReport.celsius(tenthsFahrenheit: curTemperature)
  }

  var ambientCelsius: Double {
    ProbeReport.celsius(tenthsFahrenheit: curAmbientTemperature)
  }

  /// All five sensors, in order along the shaft. Zone one is at the pointed
  /// end, and there is no name for it beyond its number: naming one of the
  /// five invites reaching for the wrong one.
  var zonesCelsius: [Double] {
    areaTemperature.map(ProbeReport.celsius(tenthsFahrenheit:))
  }
}

public extension ProbeReport {
  /// Tenths of a degree Fahrenheit, which is what the wire carries.
  static func celsius(tenthsFahrenheit tenths: Int) -> Double {
    (Double(tenths) / 10 - 32) * 5 / 9
  }
}
