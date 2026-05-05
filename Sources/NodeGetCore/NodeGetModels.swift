import Foundation

public struct ServerProfile: Identifiable, Codable, Equatable {
    public let id: UUID
    public var name: String
    public var baseURL: URL
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        baseURL: URL,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.baseURL = baseURL
        self.createdAt = createdAt
    }
}

public struct AgentMeta: Codable, Equatable {
    public var name: String
    public var region: String
    public var tags: [String]
    public var hidden: Bool
    public var virtualization: String
    public var price: Double
    public var priceUnit: String
    public var priceCycle: Int
    public var expireTime: String

    public init(
        name: String = "",
        region: String = "",
        tags: [String] = [],
        hidden: Bool = false,
        virtualization: String = "",
        price: Double = 0,
        priceUnit: String = "$",
        priceCycle: Int = 30,
        expireTime: String = ""
    ) {
        self.name = name
        self.region = region
        self.tags = tags
        self.hidden = hidden
        self.virtualization = virtualization
        self.price = price
        self.priceUnit = priceUnit
        self.priceCycle = priceCycle
        self.expireTime = expireTime
    }

    public var displayPrice: String {
        guard price > 0 else { return "--" }
        let clean = price.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(price)) : String(format: "%.2f", price)
        return "\(priceUnit)\(clean)"
    }

    public var cycleText: String {
        guard priceCycle > 0 else { return "--" }
        if priceCycle == 30 { return "月付" }
        if priceCycle == 365 { return "年付" }
        return "\(priceCycle) 天"
    }

    public var expiryDate: Date? {
        guard !expireTime.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        if let seconds = Double(expireTime) {
            return Date(timeIntervalSince1970: seconds > 1_000_000_000_000 ? seconds / 1000 : seconds)
        }

        let formatters: [DateFormatter] = {
            let a = DateFormatter()
            a.dateFormat = "yyyy-MM-dd"
            a.timeZone = .current

            let b = DateFormatter()
            b.dateFormat = "yyyy-MM-dd HH:mm:ss"
            b.timeZone = .current

            let c = DateFormatter()
            c.dateFormat = "yyyy/MM/dd"
            c.timeZone = .current
            return [a, b, c]
        }()

        for formatter in formatters {
            if let date = formatter.date(from: expireTime) { return date }
        }
        return nil
    }

    public var remainingDays: Int? {
        guard let expiryDate else { return nil }
        let seconds = expiryDate.timeIntervalSince(Date())
        return Int(ceil(seconds / 86_400))
    }
}

public struct AgentSummary: Codable, Equatable, Identifiable {
    public var id: String { uuid }

    public let uuid: String
    public let timestamp: Int64?
    public let cpuUsage: Double?
    public let gpuUsage: Double?
    public let usedSwap: Int64?
    public let totalSwap: Int64?
    public let usedMemory: Int64?
    public let totalMemory: Int64?
    public let availableMemory: Int64?
    public let loadOne: Double?
    public let loadFive: Double?
    public let loadFifteen: Double?
    public let uptime: Int64?
    public let bootTime: Int64?
    public let processCount: Int?
    public let totalSpace: Int64?
    public let availableSpace: Int64?
    public let readSpeed: Double?
    public let writeSpeed: Double?
    public let tcpConnections: Int?
    public let udpConnections: Int?
    public let totalReceived: Int64?
    public let totalTransmitted: Int64?
    public let receiveSpeed: Double?
    public let transmitSpeed: Double?

    public static let defaultFields = [
        "cpu_usage",
        "gpu_usage",
        "used_swap",
        "total_swap",
        "used_memory",
        "total_memory",
        "available_memory",
        "load_one",
        "load_five",
        "load_fifteen",
        "uptime",
        "boot_time",
        "process_count",
        "total_space",
        "available_space",
        "read_speed",
        "write_speed",
        "tcp_connections",
        "udp_connections",
        "total_received",
        "total_transmitted",
        "receive_speed",
        "transmit_speed"
    ]

    enum CodingKeys: String, CodingKey {
        case uuid
        case timestamp
        case cpuUsage = "cpu_usage"
        case gpuUsage = "gpu_usage"
        case usedSwap = "used_swap"
        case totalSwap = "total_swap"
        case usedMemory = "used_memory"
        case totalMemory = "total_memory"
        case availableMemory = "available_memory"
        case loadOne = "load_one"
        case loadFive = "load_five"
        case loadFifteen = "load_fifteen"
        case uptime
        case bootTime = "boot_time"
        case processCount = "process_count"
        case totalSpace = "total_space"
        case availableSpace = "available_space"
        case readSpeed = "read_speed"
        case writeSpeed = "write_speed"
        case tcpConnections = "tcp_connections"
        case udpConnections = "udp_connections"
        case totalReceived = "total_received"
        case totalTransmitted = "total_transmitted"
        case receiveSpeed = "receive_speed"
        case transmitSpeed = "transmit_speed"
    }

    public init(
        uuid: String,
        timestamp: Int64? = nil,
        cpuUsage: Double? = nil,
        gpuUsage: Double? = nil,
        usedSwap: Int64? = nil,
        totalSwap: Int64? = nil,
        usedMemory: Int64? = nil,
        totalMemory: Int64? = nil,
        availableMemory: Int64? = nil,
        loadOne: Double? = nil,
        loadFive: Double? = nil,
        loadFifteen: Double? = nil,
        uptime: Int64? = nil,
        bootTime: Int64? = nil,
        processCount: Int? = nil,
        totalSpace: Int64? = nil,
        availableSpace: Int64? = nil,
        readSpeed: Double? = nil,
        writeSpeed: Double? = nil,
        tcpConnections: Int? = nil,
        udpConnections: Int? = nil,
        totalReceived: Int64? = nil,
        totalTransmitted: Int64? = nil,
        receiveSpeed: Double? = nil,
        transmitSpeed: Double? = nil
    ) {
        self.uuid = uuid
        self.timestamp = timestamp
        self.cpuUsage = cpuUsage
        self.gpuUsage = gpuUsage
        self.usedSwap = usedSwap
        self.totalSwap = totalSwap
        self.usedMemory = usedMemory
        self.totalMemory = totalMemory
        self.availableMemory = availableMemory
        self.loadOne = loadOne
        self.loadFive = loadFive
        self.loadFifteen = loadFifteen
        self.uptime = uptime
        self.bootTime = bootTime
        self.processCount = processCount
        self.totalSpace = totalSpace
        self.availableSpace = availableSpace
        self.readSpeed = readSpeed
        self.writeSpeed = writeSpeed
        self.tcpConnections = tcpConnections
        self.udpConnections = udpConnections
        self.totalReceived = totalReceived
        self.totalTransmitted = totalTransmitted
        self.receiveSpeed = receiveSpeed
        self.transmitSpeed = transmitSpeed
    }

    public var memoryUsagePercent: Double? {
        guard let usedMemory, let totalMemory, totalMemory > 0 else { return nil }
        return Double(usedMemory) / Double(totalMemory) * 100
    }

    public var diskUsagePercent: Double? {
        guard let totalSpace, let availableSpace, totalSpace > 0 else { return nil }
        let used = totalSpace - availableSpace
        return Double(used) / Double(totalSpace) * 100
    }

    public var swapUsagePercent: Double? {
        guard let usedSwap, let totalSwap, totalSwap > 0 else { return nil }
        return Double(usedSwap) / Double(totalSwap) * 100
    }

    public var memoryUsedText: String {
        "\(NodeGetFormatters.bytes(usedMemory)) / \(NodeGetFormatters.bytes(totalMemory))"
    }

    public var diskUsedText: String {
        guard let totalSpace, let availableSpace else { return "--" }
        return "\(NodeGetFormatters.bytes(totalSpace - availableSpace)) / \(NodeGetFormatters.bytes(totalSpace))"
    }

    public var swapUsedText: String {
        "\(NodeGetFormatters.bytes(usedSwap)) / \(NodeGetFormatters.bytes(totalSwap))"
    }
}

public struct KVValueRow: Decodable, Equatable {
    public let namespace: String
    public let key: String
    public let value: JSONValue?

    public init(namespace: String, key: String, value: JSONValue?) {
        self.namespace = namespace
        self.key = key
        self.value = value
    }
}

public enum JSONValue: Decodable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    public init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() {
            self = .null
        } else if let value = try? c.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? c.decode(Double.self) {
            self = .number(value)
        } else if let value = try? c.decode(String.self) {
            self = .string(value)
        } else if let value = try? c.decode([String: JSONValue].self) {
            self = .object(value)
        } else if let value = try? c.decode([JSONValue].self) {
            self = .array(value)
        } else {
            self = .null
        }
    }

    public var stringValue: String? {
        switch self {
        case .string(let v): return v
        case .number(let v):
            return v.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(v)) : String(v)
        case .bool(let v): return v ? "true" : "false"
        case .null: return nil
        case .array, .object: return nil
        }
    }

    public var doubleValue: Double? {
        switch self {
        case .number(let v): return v
        case .string(let s): return Double(s)
        case .bool(let b): return b ? 1 : 0
        case .null, .array, .object: return nil
        }
    }

    public var boolValue: Bool? {
        switch self {
        case .bool(let v): return v
        case .string(let s): return ["true", "1", "yes"].contains(s.lowercased())
        case .number(let n): return n != 0
        case .null, .array, .object: return nil
        }
    }

    public var stringArrayValue: [String]? {
        switch self {
        case .array(let values):
            return values.compactMap { $0.stringValue }
        case .string(let s):
            return s.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        default:
            return nil
        }
    }

    public func firstNumber(depth: Int = 0) -> Double? {
        if depth > 5 { return nil }
        switch self {
        case .number(let v): return v
        case .string(let s):
            let pattern = #"-?\d+(?:\.\d+)?"#
            guard let range = s.range(of: pattern, options: .regularExpression) else { return nil }
            return Double(s[range])
        case .array(let values):
            for value in values.reversed() {
                if let number = value.firstNumber(depth: depth + 1) { return number }
            }
            return nil
        case .object(let object):
            let keys = ["latency", "delay", "rtt", "time", "ms", "avg", "value", "result", "duration", "ping", "tcp_ping"]
            for key in keys {
                if let number = object[key]?.firstNumber(depth: depth + 1) { return number }
            }
            for value in object.values {
                if let number = value.firstNumber(depth: depth + 1) { return number }
            }
            return nil
        case .bool, .null:
            return nil
        }
    }
}

public struct TaskQueryResult: Decodable, Equatable, Identifiable {
    public var id: String { "\(taskID ?? 0)-\(timestamp)-\(cronSource ?? "")" }

    public let taskID: Int?
    public let timestamp: Int64
    public let uuid: String
    public let success: Bool?
    public let errorMessage: String?
    public let cronSource: String?
    public let taskEventType: JSONValue?
    public let taskEventResult: JSONValue?

    enum CodingKeys: String, CodingKey {
        case taskID = "task_id"
        case timestamp
        case uuid
        case success
        case errorMessage = "error_message"
        case cronSource = "cron_source"
        case taskEventType = "task_event_type"
        case taskEventResult = "task_event_result"
    }

    public func latencyValue(type: String) -> Double? {
        guard success != false, let taskEventResult else { return nil }
        if case .object(let object) = taskEventResult, let direct = object[type]?.firstNumber() {
            return direct
        }
        return taskEventResult.firstNumber()
    }
}

public struct LatencyStats: Identifiable, Equatable {
    public var id: String { name }

    public let name: String
    public let avg: Double?
    public let jitter: Double?
    public let lossRate: Double
    public let values: [Double?]
    public let timestamps: [Int64?]

    public init(name: String, avg: Double?, jitter: Double?, lossRate: Double, values: [Double?], timestamps: [Int64?] = []) {
        self.name = name
        self.avg = avg
        self.jitter = jitter
        self.lossRate = lossRate
        self.values = values
        self.timestamps = timestamps
    }
}
