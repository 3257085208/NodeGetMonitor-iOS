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

    public static func speed(_ value: Int64?) -> String {
        guard let value else { return "--" }
        return bytes(value) + "/s"
    }

    public static func relativeTime(milliseconds: Int64?) -> String {
        guard let milliseconds else { return "--" }
        let seconds = Int(Date().timeIntervalSince1970 - TimeInterval(milliseconds) / 1000)
        if seconds < 60 {
            return "刚刚"
        }
        let minutes = seconds / 60
        if minutes < 60 {
            return "\(minutes) 分钟前"
        }
        let hours = minutes / 60
        if hours < 24 {
            return "\(hours) 小时前"
        }
        let days = hours / 24
        return "\(days) 天前"
    }

    public static func uptime(_ seconds: Int64?) -> String {
        guard let seconds else { return "--" }
        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3_600
        let minutes = (seconds % 3_600) / 60

        if days > 0 {
            return "\(days)天 \(hours)小时"
        } else if hours > 0 {
            return "\(hours)小时 \(minutes)分钟"
        } else {
            return "\(minutes)分钟"
        }
    }
}
