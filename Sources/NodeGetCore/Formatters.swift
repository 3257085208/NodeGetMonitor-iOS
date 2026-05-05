import Foundation

public enum NodeGetFormatters {
    public static func percent(_ value: Double?) -> String {
        guard let value else { return "--" }
        return String(format: "%.1f%%", value)
    }

    public static func bytes(_ value: Int64?) -> String {
        guard let value else { return "--" }
        if value == 0 { return "0 KB" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB, .useTB]
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: value).replacingOccurrences(of: "Zero", with: "0")
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
        if seconds < 60 { return "刚刚" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes) 分钟前" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours) 小时前" }
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

    public static func date(_ date: Date?) -> String {
        guard let date else { return "--" }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    public static func milliseconds(_ value: Double?) -> String {
        guard let value else { return "--" }
        return String(format: "%.1f ms", value)
    }

    public static func days(_ value: Int?) -> String {
        guard let value else { return "--" }
        return "\(value) 天"
    }

    public static func clockTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }

    public static func clockTime(milliseconds: Int64?) -> String {
        guard let milliseconds else { return "--" }
        let date = Date(timeIntervalSince1970: TimeInterval(milliseconds) / 1000)
        return clockTime(date)
    }

    public static func dateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: date)
    }

}

public enum NodeGetStats {
    public static func onlineRate(from rows: [AgentSummary], now: Date = Date(), windowSeconds: Double = 3600) -> Double {
        guard !rows.isEmpty else { return 0 }
        let cutoff = now.timeIntervalSince1970 * 1000 - windowSeconds * 1000
        let recent = rows.filter { Double($0.timestamp ?? 0) >= cutoff }
        guard !recent.isEmpty else { return 0 }
        let online = recent.filter { summary in
            let age = now.timeIntervalSince1970 * 1000 - Double(summary.timestamp ?? 0)
            return age >= 0 && age <= 120_000
        }
        return Double(online.count) / Double(recent.count) * 100
    }

    public static func latencyStats(rows: [TaskQueryResult], type: String, buckets: Int = 36) -> [LatencyStats] {
        let grouped = Dictionary(grouping: rows) { row in
            let source = row.cronSource?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return source.isEmpty ? (type == "tcp_ping" ? "TCP Ping" : "Ping") : source
        }

        return grouped.map { name, rows in
            let sorted = rows.sorted { $0.timestamp < $1.timestamp }
            let rawValues = sorted.map { $0.latencyValue(type: type) }
            let rawTimes = sorted.map { Optional($0.timestamp) }
            let bucketed = bucket(values: rawValues, timestamps: rawTimes, buckets: buckets)
            let valid = rawValues.compactMap { $0 }
            let avg = valid.isEmpty ? nil : valid.reduce(0, +) / Double(valid.count)
            let jitter = calculateJitter(valid)
            let loss = rawValues.isEmpty ? 0 : Double(rawValues.filter { $0 == nil }.count) / Double(rawValues.count) * 100
            return LatencyStats(name: name, avg: avg, jitter: jitter, lossRate: loss, values: bucketed.values, timestamps: bucketed.timestamps)
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private static func bucket(values: [Double?], timestamps: [Int64?], buckets: Int) -> (values: [Double?], timestamps: [Int64?]) {
        guard buckets > 0 else { return ([], []) }
        if values.isEmpty { return (Array(repeating: nil, count: buckets), Array(repeating: nil, count: buckets)) }
        if values.count <= buckets {
            let pad = max(0, buckets - values.count)
            return (Array(repeating: nil, count: pad) + values, Array(repeating: nil, count: pad) + timestamps)
        }

        var outputValues: [Double?] = []
        var outputTimes: [Int64?] = []
        for i in 0..<buckets {
            let start = i * values.count / buckets
            let end = max(start + 1, (i + 1) * values.count / buckets)
            let safeEnd = min(end, values.count)
            let slice = values[start..<safeEnd].compactMap { $0 }
            outputValues.append(slice.isEmpty ? nil : slice.reduce(0, +) / Double(slice.count))
            outputTimes.append(timestamps[min(max(start, 0), timestamps.count - 1)])
        }
        return (outputValues, outputTimes)
    }

    private static func calculateJitter(_ values: [Double]) -> Double? {
        guard values.count > 1 else { return nil }
        let diffs = zip(values.dropFirst(), values).map { abs($0 - $1) }
        return diffs.reduce(0, +) / Double(diffs.count)
    }

}
