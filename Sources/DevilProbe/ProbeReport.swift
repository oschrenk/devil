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

  public struct Body: Decodable, Sendable {
    /// The base station's own battery, as a percentage.
    public var batteryValue: Int?
    public var wifiRssi: Int?
    public var probes: [Probe]
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
    /// and `tipCelsius` is the right one.
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
    return try? JSONDecoder().decode(ProbeReport.self, from: Data(json))
  }
}

public extension ProbeReport.Probe {
  /// The tip, in the units the rest of the app speaks.
  ///
  /// The first zone, which is the sensor at the pointed end. Deliberately not
  /// `curTemperature`, which is the coldest zone wherever it happens to be.
  var tipCelsius: Double? {
    areaTemperature.first.map(ProbeReport.celsius(tenthsFahrenheit:))
  }

  /// The coldest of the five, as the device computes it. What the vendor's app
  /// calls `Meat`.
  var coldestCelsius: Double {
    ProbeReport.celsius(tenthsFahrenheit: curTemperature)
  }

  var ambientCelsius: Double {
    ProbeReport.celsius(tenthsFahrenheit: curAmbientTemperature)
  }

  /// All five sensors, tip first.
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
