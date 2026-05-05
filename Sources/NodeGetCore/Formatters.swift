import Foundation

public enum NodeGetFormatters {
    public static func percent(_ value: Double?) -> String {
        guard let value else { return "--" }
        return String(format: "%.1f%%", value)
    }

    public static func bytes(_ value: Int64?) -> String {
        guard let value else { return "--" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: value)
    }

    public static func speed(_ value: Double?) -> String {
        guard let value else { return "--" }
        return bytes(Int64(value)) + "/s"
    }
}
