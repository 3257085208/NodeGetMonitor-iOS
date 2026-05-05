import SwiftUI

struct ServerDetailView: View {
    @EnvironmentObject private var serverStore: ServerProfileStore
    @Environment(\.dismiss) private var dismiss

    let profile: ServerProfile

    @State private var serverMessage = "尚未刷新"
    @State private var agentUUIDs: [String] = []
    @State private var summaries: [AgentSummary] = []
    @State private var staticInfoByUUID: [String: StaticAgentInfo] = [:]
    @State private var metaByUUID: [String: AgentMeta] = [:]
    @State private var isLoading = false
    @State private var showDeleteConfirmation = false
    @State private var searchText = ""

    var body: some View {
        ZStack {
            AppBackgroundView()
            contentScroll
        }
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "搜索节点…")
        .task {
            await refreshAll()
            await autoRefreshLoop()
        }
        .refreshable {
            await refreshAll()
        }
        .confirmationDialog("确定删除这个服务器？", isPresented: $showDeleteConfirmation) {
            Button("删除", role: .destructive) {
                serverStore.delete(profile)
                dismiss()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("服务器配置和对应 Token 都会从本机删除。")
        }
    }

    private var contentScroll: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                headerView

                if filteredSummaries.isEmpty {
                    emptyView
                } else {
                    agentListView
                }

                deleteButton
            }
            .padding(20)
        }
    }

    private var headerView: some View {
        ServerSummaryHeaderView(
            title: profile.name,
            subtitle: profile.baseURL.absoluteString,
            statusText: serverMessage,
            agentCount: filteredSummaries.count,
            loading: isLoading,
            refreshAction: {
                Task { await refreshAll() }
            }
        )
    }

    private var emptyView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("暂无 Agent 数据")
                .font(.system(size: 24, weight: .black, design: .rounded))
            Text(isLoading ? "正在读取节点监控数据…" : "点击刷新后会读取真实节点数据。")
                .font(.subheadline)
                .foregroundStyle(Color.ngMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .ngSoftCard()
    }

    private var agentListView: some View {
        ForEach(filteredSummaries) { summary in
            agentNavigationLink(for: summary)
        }
    }

    private func agentNavigationLink(for summary: AgentSummary) -> some View {
        let uuid = summary.uuid
        let staticInfo = staticInfoByUUID[uuid]
        let meta = metaByUUID[uuid]

        return NavigationLink {
            AgentDetailView(
                server: profile,
                uuid: uuid,
                summary: summary,
                staticInfo: staticInfo,
                meta: meta
            )
        } label: {
            DashboardAgentCardView(
                summary: summary,
                staticInfo: staticInfo,
                meta: meta
            )
        }
        .buttonStyle(.plain)
    }

    private var deleteButton: some View {
        Button(role: .destructive) {
            showDeleteConfirmation = true
        } label: {
            Label("删除服务器", systemImage: "trash")
                .font(.title3.bold())
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
        }
        .foregroundStyle(.red)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.75))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.ngBorder, lineWidth: 1)
        )
        .padding(.top, 4)
    }

    private var filteredSummaries: [AgentSummary] {
        let sorted = summaries.sorted { left, right in
            let leftName = displayName(for: left.uuid)
            let rightName = displayName(for: right.uuid)
            return leftName.localizedCaseInsensitiveCompare(rightName) == .orderedAscending
        }

        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return sorted }

        return sorted.filter { summary in
            searchTextBlob(for: summary.uuid).localizedCaseInsensitiveContains(keyword)
        }
    }

    private func displayName(for uuid: String) -> String {
        if let name = metaByUUID[uuid]?.name.nilIfEmpty { return name }
        if let name = staticInfoByUUID[uuid]?.displayName.nilIfEmpty { return name }
        return uuid
    }

    private func searchTextBlob(for uuid: String) -> String {
        let info = staticInfoByUUID[uuid]
        let meta = metaByUUID[uuid]
        return [
            uuid,
            meta?.name ?? "",
            meta?.region ?? "",
            info?.displayName ?? "",
            info?.systemLine ?? "",
            info?.cpuLine ?? ""
        ].joined(separator: " ")
    }

    private func autoRefreshLoop() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if Task.isCancelled { break }
            await refreshAll(showLoading: false)
        }
    }

    private func refreshAll(showLoading: Bool = true) async {
        guard !isLoading else { return }

        guard let token = KeychainStore.shared.token(for: profile.id) else {
            serverMessage = "未找到 Token。请删除后重新添加服务器。"
            return
        }

        if showLoading { isLoading = true }
        defer {
            if showLoading { isLoading = false }
        }

        do {
            let client = NodeGetClient(baseURL: profile.baseURL)
            let hello = try await client.hello()
            let uuids = try await client.listAllAgentUUIDs(token: token)
            agentUUIDs = uuids.sorted()

            let latestSummaries = try await client.latestDynamicSummaries(token: token, uuids: agentUUIDs)
            LocalTrendStore.shared.append(contentsOf: latestSummaries)
            summaries = latestSummaries.sorted { $0.uuid < $1.uuid }

            do {
                staticInfoByUUID = try await client.latestStaticInfoMap(token: token, uuids: agentUUIDs)
            } catch {
                staticInfoByUUID = [:]
            }

            do {
                metaByUUID = try await client.metadataMap(token: token, uuids: agentUUIDs)
            } catch {
                metaByUUID = [:]
            }

            let hiddenUUIDs = Set(metaByUUID.filter { $0.value.hidden }.map(\.key))
            if !hiddenUUIDs.isEmpty {
                summaries = summaries.filter { !hiddenUUIDs.contains($0.uuid) }
            }

            serverMessage = "连接成功：\(hello)；读取到 \(agentUUIDs.count) 个 Agent。自动刷新：\(NodeGetFormatters.clockTime(Date()))"
        } catch {
            serverMessage = "刷新失败：\(error.localizedDescription)"
        }
    }
}
