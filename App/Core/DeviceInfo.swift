import Foundation
import UIKit

public struct DeviceSnapshot: Equatable {
    public let model: String
    public let system: String
    public let name: String
    public let locale: String
    public let timezone: String
    public let totalDisk: Int64
    public let freeDisk: Int64
    public let totalMemory: UInt64
    public let battery: Float
    public let batteryState: String
    public let screen: String
}

public enum DeviceInfo {
    public static func snapshot() -> DeviceSnapshot {
        let fm = FileManager.default
        let attrs = try? fm.attributesOfFileSystem(forPath: NSHomeDirectory())
        let total = (attrs?[.systemSize] as? NSNumber)?.int64Value ?? 0
        let free = (attrs?[.systemFreeSize] as? NSNumber)?.int64Value ?? 0
        UIDevice.current.isBatteryMonitoringEnabled = true
        let bat = UIDevice.current.batteryLevel
        let state: String = {
            switch UIDevice.current.batteryState {
            case .charging: return "يشحن"
            case .full: return "ممتلئ"
            case .unplugged: return "على البطارية"
            default: return "غير معروف"
            }
        }()
        let bounds = UIScreen.main.bounds
        let scale = UIScreen.main.scale
        return DeviceSnapshot(
            model: machineIdentifier(),
            system: "iOS \(UIDevice.current.systemVersion)",
            name: UIDevice.current.name,
            locale: Locale.current.identifier,
            timezone: TimeZone.current.identifier,
            totalDisk: total, freeDisk: free,
            totalMemory: ProcessInfo.processInfo.physicalMemory,
            battery: bat, batteryState: state,
            screen: "\(Int(bounds.width))×\(Int(bounds.height)) @\(Int(scale))x")
    }

    public static func machineIdentifier() -> String {
        var size = 0
        sysctlbyname("hw.machine", nil, &size, nil, 0)
        var machine = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.machine", &machine, &size, nil, 0)
        return String(cString: machine)
    }

    public static func humanBytes(_ n: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: n, countStyle: .file)
    }
}
