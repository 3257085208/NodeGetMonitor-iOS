import Foundation

@MainActor
final class LocalTrendStore {
    static let shared = LocalTrendStore()

    private var samplesByUUID: [String: [AgentSummary]] = [:]
    private let windowMilliseconds: Int64 = 240_000
    private let maxSamples = 180

    private init() {}

    func append(_ summary: AgentSummary) {
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let normalized: AgentSummary
        if let last = samplesByUUID[summary.uuid]?.last, let lastTimestamp = last.timestamp {
            let incoming = summary.timestamp ?? now
            normalized = incoming <= lastTimestamp ? summary.withTimestamp(now) : summary
        } else {
            normalized = summary.timestamp == nil ? summary.withTimestamp(now) : summary
        }

        var list = samplesByUUID[summary.uuid, default: []]
        if let last = list.last, last.timestamp == normalized.timestamp {
            list[list.count - 1] = normalized
        } else {
            list.append(normalized)
        }
        samplesByUUID[summary.uuid] = trimmed(list, now: now)
    }

    func append(contentsOf summaries: [AgentSummary]) {
        for summary in summaries {
            append(summary)
        }
    }

    func mergeRemote(_ rows: [AgentSummary], for uuid: String) {
        guard !rows.isEmpty else { return }
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        var merged = samplesByUUID[uuid, default: []]
        merged.append(contentsOf: rows)
        var dedup: [Int64: AgentSummary] = [:]
        for row in merged {
            let ts = row.timestamp ?? now
            dedup[ts] = row.timestamp == nil ? row.withTimestamp(ts) : row
        }
        samplesByUUID[uuid] = trimmed(dedup.values.sorted { ($0.timestamp ?? 0) < ($1.timestamp ?? 0) }, now: now)
    }

    func history(for uuid: String) -> [AgentSummary] {
        let now = Int64(Date().timeIntervalSince1970 * 1000)
        let list = trimmed(samplesByUUID[uuid, default: []], now: now)
        samplesByUUID[uuid] = list
        return list
    }

    private func trimmed(_ list: [AgentSummary], now: Int64) -> [AgentSummary] {
        let cutoff = now - windowMilliseconds
        let recent = list
            .filter { ($0.timestamp ?? now) >= cutoff }
            .sorted { ($0.timestamp ?? 0) < ($1.timestamp ?? 0) }
        if recent.count > maxSamples {
            return Array(recent.suffix(maxSamples))
        }
        return recent
    }
}

extension AgentSummary {
    func withTimestamp(_ timestamp: Int64) -> AgentSummary {
        AgentSummary(
            uuid: uuid,
            timestamp: timestamp,
            cpuUsage: cpuUsage,
            gpuUsage: gpuUsage,
            usedSwap: usedSwap,
            totalSwap: totalSwap,
            usedMemory: usedMemory,
            totalMemory: totalMemory,
            availableMemory: availableMemory,
            loadOne: loadOne,
            loadFive: loadFive,
            loadFifteen: loadFifteen,
            uptime: uptime,
            bootTime: bootTime,
            processCount: processCount,
            totalSpace: totalSpace,
            availableSpace: availableSpace,
            readSpeed: readSpeed,
            writeSpeed: writeSpeed,
            tcpConnections: tcpConnections,
            udpConnections: udpConnections,
            totalReceived: totalReceived,
            totalTransmitted: totalTransmitted,
            receiveSpeed: receiveSpeed,
            transmitSpeed: transmitSpeed
        )
    }
}
