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
    public let receiveSpeed: Double?
    public let transmitSpeed: Double?
    public let gpuUsage: Double?

    public static let defaultFields = [
        "cpu_usage",
        "used_memory",
        "total_memory",
        "available_memory",
        "total_space",
        "available_space",
        "receive_speed",
        "transmit_speed",
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
        case receiveSpeed = "receive_speed"
        case transmitSpeed = "transmit_speed"
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
        receiveSpeed: Double? = nil,
        transmitSpeed: Double? = nil,
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
        self.receiveSpeed = receiveSpeed
        self.transmitSpeed = transmitSpeed
        self.gpuUsage = gpuUsage
    }
}
