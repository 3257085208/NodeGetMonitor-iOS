import Foundation

public struct StaticAgentInfo: Decodable, Equatable, Identifiable {
    public var id: String { uuid }

    public let uuid: String
    public let timestamp: Int64?
    public let cpu: StaticCPUData?
    public let system: StaticSystemData?

    public init(uuid: String, timestamp: Int64?, cpu: StaticCPUData?, system: StaticSystemData?) {
        self.uuid = uuid
        self.timestamp = timestamp
        self.cpu = cpu
        self.system = system
    }

    public var displayName: String {
        let host = system?.systemHostName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return host.isEmpty ? uuid : host
    }

    public var systemLine: String {
        var parts: [String] = []
        if let os = system?.systemOsLongVersion, !os.isEmpty {
            parts.append(os)
        } else if let name = system?.systemName, !name.isEmpty {
            parts.append(name)
        }

        if let virtualization = system?.virtualization, !virtualization.isEmpty, virtualization.lowercased() != "unknown" {
            parts.append(virtualization)
        }
        return parts.joined(separator: " · ")
    }

    public var cpuLine: String {
        var parts: [String] = []
        if let cores = cpu?.logicalCores {
            parts.append("\(cores) 核")
        }
        if let brand = cpu?.perCore.first?.brand, !brand.isEmpty {
            parts.append(brand)
        }
        return parts.joined(separator: " · ")
    }
}

public struct StaticCPUData: Decodable, Equatable {
    public let physicalCores: Int?
    public let logicalCores: Int?
    public let perCore: [StaticPerCpuCoreData]

    enum CodingKeys: String, CodingKey {
        case physicalCores = "physical_cores"
        case logicalCores = "logical_cores"
        case perCore = "per_core"
    }

    public init(physicalCores: Int?, logicalCores: Int?, perCore: [StaticPerCpuCoreData]) {
        self.physicalCores = physicalCores
        self.logicalCores = logicalCores
        self.perCore = perCore
    }
}

public struct StaticPerCpuCoreData: Decodable, Equatable {
    public let id: Int?
    public let name: String?
    public let vendorID: String?
    public let brand: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case vendorID = "vendor_id"
        case brand
    }

    public init(id: Int?, name: String?, vendorID: String?, brand: String?) {
        self.id = id
        self.name = name
        self.vendorID = vendorID
        self.brand = brand
    }
}

public struct StaticSystemData: Decodable, Equatable {
    public let systemName: String?
    public let systemKernel: String?
    public let systemKernelVersion: String?
    public let systemOsVersion: String?
    public let systemOsLongVersion: String?
    public let distributionID: String?
    public let systemHostName: String?
    public let arch: String?
    public let virtualization: String?

    enum CodingKeys: String, CodingKey {
        case systemName = "system_name"
        case systemKernel = "system_kernel"
        case systemKernelVersion = "system_kernel_version"
        case systemOsVersion = "system_os_version"
        case systemOsLongVersion = "system_os_long_version"
        case distributionID = "distribution_id"
        case systemHostName = "system_host_name"
        case arch
        case virtualization
    }

    public init(
        systemName: String?,
        systemKernel: String?,
        systemKernelVersion: String?,
        systemOsVersion: String?,
        systemOsLongVersion: String?,
        distributionID: String?,
        systemHostName: String?,
        arch: String?,
        virtualization: String?
    ) {
        self.systemName = systemName
        self.systemKernel = systemKernel
        self.systemKernelVersion = systemKernelVersion
        self.systemOsVersion = systemOsVersion
        self.systemOsLongVersion = systemOsLongVersion
        self.distributionID = distributionID
        self.systemHostName = systemHostName
        self.arch = arch
        self.virtualization = virtualization
    }
}
