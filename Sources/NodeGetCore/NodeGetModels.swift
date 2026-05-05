import Foundation

public struct ServerProfile: Identifiable, Codable, Equatable {
    public let id: UUID
    public var name: String
    public var baseURL: URL

    public init(id: UUID = UUID(), name: String, baseURL: URL) {
        self.id = id
        self.name = name
        self.baseURL = baseURL
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
