import SwiftUI

@MainActor
final class ServerDashboardDataStore: ObservableObject {
    let profile: ServerProfile

    @Published var serverMessage = "正在读取 Agent 数据…"
    @Published var agentUUIDs: [String] = []
    @Published var summaries: [AgentSummary] = []
    @Published var staticInfoByUUID: [String: StaticAgentInfo] = [:]
    @Published var metaByUUID: [String: AgentMeta] = [:]
    @Published var isLoading = false
    @Published var lastRefresh: Date?
    private var isRefreshing = false

    init(profile: ServerProfile) {
        self.profile = profile
    }

    func refresh(showLoading: Bool = true) async {
        guard !isRefreshing else { return }

        guard let token = KeychainStore.shared.token(for: profile.id) else {
            serverMessage = "未找到 Token。请到下方“设置”页重新添加主控。"
            return
        }

        isRefreshing = true
        if showLoading { isLoading = true }
        defer {
            isRefreshing = false
            if showLoading { isLoading = false }
        }

        do {
            let client = NodeGetClient(baseURL: profile.baseURL)
            let hello = try await client.hello()
            let uuids = try await client.listAllAgentUUIDs(token: token)
            let sortedUUIDs = uuids.sorted()
            agentUUIDs = sortedUUIDs

            let latestSummaries = try await client.latestDynamicSummaries(token: token, uuids: sortedUUIDs)
            LocalTrendStore.shared.append(contentsOf: latestSummaries)
            summaries = latestSummaries.sorted { left, right in
                displayName(for: left.uuid).localizedCaseInsensitiveCompare(displayName(for: right.uuid)) == .orderedAscending
            }

            do {
                staticInfoByUUID = try await client.latestStaticInfoMap(token: token, uuids: sortedUUIDs)
            } catch {
                // 静态信息失败不阻断总览刷新
            }

            do {
                metaByUUID = try await client.metadataMap(token: token, uuids: sortedUUIDs)
            } catch {
                // 元数据失败不阻断总览刷新
            }

            lastRefresh = Date()
            serverMessage = "连接成功：\(hello)；读取到 \(sortedUUIDs.count) 个 Agent。每 1 秒自动刷新于 \(NodeGetFormatters.clockTime(Date()))。"
        } catch {
            serverMessage = "刷新失败：\(error.localizedDescription)"
        }
    }

    func displayName(for uuid: String) -> String {
        metaByUUID[uuid]?.name.nilIfEmpty ?? staticInfoByUUID[uuid]?.displayName ?? uuid
    }

    func filteredSummaries(searchText: String) -> [AgentSummary] {
        let sorted = summaries.sorted { left, right in
            displayName(for: left.uuid).localizedCaseInsensitiveCompare(displayName(for: right.uuid)) == .orderedAscending
        }

        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return sorted }

        return sorted.filter { summary in
            let uuid = summary.uuid
            let info = staticInfoByUUID[uuid]
            let meta = metaByUUID[uuid]
            let candidates = [
                uuid,
                displayName(for: uuid),
                meta?.region ?? "",
                info?.systemLine ?? "",
                info?.cpuLine ?? ""
            ]
            return candidates.joined(separator: " ").localizedCaseInsensitiveContains(keyword)
        }
    }
}
