import SwiftUI

struct ServerDetailView: View {
    @EnvironmentObject private var serverStore: ServerProfileStore
    @Environment(\.dismiss) private var dismiss

    let profile: ServerProfile

    @State private var serverMessage = "尚未刷新"
    @State private var agentUUIDs: [String] = []
    @State private var summaries: [AgentSummary] = []
    @State private var staticInfoByUUID: [String: StaticAgentInfo] = [:]
    @State private var isLoading = false
    @State private var showDeleteConfirmation = false
    @State private var searchText = ""

    var body: some View {
        ZStack {
            AppBackgroundView()

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    ServerSummaryHeaderView(
                        title: profile.name,
                        subtitle: profile.baseURL.absoluteString,
                        statusText: serverMessage,
                        agentCount: filteredSummaries.count,
                        loading: isLoading
                    ) {
                        Task { await refreshAll() }
                    }

                    if filteredSummaries.isEmpty {
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
                    } else {
                        ForEach(filteredSummaries) { summary in
                            NavigationLink {
                                AgentDetailView(
                                    server: profile,
                                    uuid: summary.uuid,
                                    summary: summary,
                                    staticInfo: staticInfoByUUID[summary.uuid]
                                )
                            } label: {
                                DashboardAgentCardView(summary: summary, staticInfo: staticInfoByUUID[summary.uuid])
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("删除服务器", systemImage: "trash")
                            .font(.title3.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                    .foregroundStyle(.red)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Color.white.opacity(0.75)))
                    .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Color.ngBorder, lineWidth: 1))
                    .padding(.top, 4)
                }
                .padding(20)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "搜索节点…")
        .task {
            if summaries.isEmpty {
                await refreshAll()
            }
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

    private var filteredSummaries: [AgentSummary] {
        let sorted = summaries.sorted { left, right in
            let leftName = staticInfoByUUID[left.uuid]?.displayName ?? left.uuid
            let rightName = staticInfoByUUID[right.uuid]?.displayName ?? right.uuid
            return leftName.localizedCaseInsensitiveCompare(rightName) == .orderedAscending
        }

        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return sorted }

        return sorted.filter { summary in
            let info = staticInfoByUUID[summary.uuid]
            let candidates = [
                summary.uuid,
                info?.displayName ?? "",
                info?.systemLine ?? "",
                info?.cpuLine ?? ""
            ]
            return candidates.joined(separator: " ").localizedCaseInsensitiveContains(keyword)
        }
    }

    private func refreshAll() async {
        guard let token = KeychainStore.shared.token(for: profile.id) else {
            serverMessage = "未找到 Token。请删除后重新添加服务器。"
            return
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let client = NodeGetClient(baseURL: profile.baseURL)
            let hello = try await client.hello()
            let uuids = try await client.listAllAgentUUIDs(token: token)
            agentUUIDs = uuids.sorted()

            let latestSummaries = try await client.latestDynamicSummaries(token: token, uuids: agentUUIDs)
            summaries = latestSummaries.sorted { $0.uuid < $1.uuid }

            let staticMap = await loadStaticInfoMap(client: client, token: token, uuids: agentUUIDs)
            staticInfoByUUID = staticMap

            serverMessage = "连接成功：\(hello)；读取到 \(agentUUIDs.count) 个 Agent 的实时监控数据。"
        } catch {
            serverMessage = "刷新失败：\(error.localizedDescription)"
        }
    }

    private func loadStaticInfoMap(
        client: NodeGetClient,
        token: String,
        uuids: [String]
    ) async -> [String: StaticAgentInfo] {
        await withTaskGroup(of: (String, StaticAgentInfo?).self) { group in
            for uuid in uuids {
                group.addTask {
                    do {
                        let info = try await client.latestStaticInfo(token: token, uuid: uuid)
                        return (uuid, info)
                    } catch {
                        return (uuid, nil)
                    }
                }
            }

            var result: [String: StaticAgentInfo] = [:]
            for await (uuid, info) in group {
                if let info {
                    result[uuid] = info
                }
            }
            return result
        }
    }
}
