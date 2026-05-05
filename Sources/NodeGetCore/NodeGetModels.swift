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

public struct AgentSummary: Codable, Equatable, Identifiable {
    public var id: String { uuid }

    public let uuid: String
    public let timestamp: Int64?
    public let cpuUsage: Double?
    public let usedMemory: Int64?
    public let totalMemory: Int64?
    public let availableMemory: Int64?
    public let totalSpace: Int64?
    public let availableSpace: Int64?
    public let readSpeed: Double?
    public let writeSpeed: Double?
    public let receiveSpeed: Double?
    public let transmitSpeed: Double?
    public let uptime: Int64?
    public let processCount: Int?
    public let tcpConnections: Int?
    public let udpConnections: Int?
    public let gpuUsage: Double?

    public static let defaultFields = [
        "cpu_usage",
        "used_memory",
        "total_memory",
        "available_memory",
        "total_space",
        "available_space",
        "read_speed",
        "write_speed",
        "receive_speed",
        "transmit_speed",
        "uptime",
        "process_count",
        "tcp_connections",
        "udp_connections",
        "gpu_usage"
    ]

    enum CodingKeys: String, CodingKey {
        case uuid
        case timestamp
        case cpuUsage = "cpu_usage"
        case usedMemory = "used_memory"
        case totalMemory = "total_memory"
        case availableMemory = "available_memory"
        case totalSpace = "total_space"
        case availableSpace = "available_space"
        case readSpeed = "read_speed"
        case writeSpeed = "write_speed"
        case receiveSpeed = "receive_speed"
        case transmitSpeed = "transmit_speed"
        case uptime
        case processCount = "process_count"
        case tcpConnections = "tcp_connections"
        case udpConnections = "udp_connections"
        case gpuUsage = "gpu_usage"
    }

    public init(
        uuid: String,
        timestamp: Int64? = nil,
        cpuUsage: Double? = nil,
        usedMemory: Int64? = nil,
        totalMemory: Int64? = nil,
        availableMemory: Int64? = nil,
        totalSpace: Int64? = nil,
        availableSpace: Int64? = nil,
        readSpeed: Double? = nil,
        writeSpeed: Double? = nil,
        receiveSpeed: Double? = nil,
        transmitSpeed: Double? = nil,
        uptime: Int64? = nil,
        processCount: Int? = nil,
        tcpConnections: Int? = nil,
        udpConnections: Int? = nil,
        gpuUsage: Double? = nil
    ) {
        self.uuid = uuid
        self.timestamp = timestamp
        self.cpuUsage = cpuUsage
        self.usedMemory = usedMemory
        self.totalMemory = totalMemory
        self.availableMemory = availableMemory
        self.totalSpace = totalSpace
        self.availableSpace = availableSpace
        self.readSpeed = readSpeed
        self.writeSpeed = writeSpeed
        self.receiveSpeed = receiveSpeed
        self.transmitSpeed = transmitSpeed
        self.uptime = uptime
        self.processCount = processCount
        self.tcpConnections = tcpConnections
        self.udpConnections = udpConnections
        self.gpuUsage = gpuUsage
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
}
