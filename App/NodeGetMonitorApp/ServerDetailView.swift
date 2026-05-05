import SwiftUI

struct ServerDetailView: View {
    @EnvironmentObject private var serverStore: ServerProfileStore
    @Environment(\.dismiss) private var dismiss

    let profile: ServerProfile

    @State private var serverMessage = "尚未刷新"
    @State private var agentUUIDs: [String] = []
    @State private var isLoading = false
    @State private var showDeleteConfirmation = false

    var body: some View {
        List {
            Section("服务器") {
                LabeledContent("名称", value: profile.name)
                LabeledContent("地址", value: profile.baseURL.absoluteString)
                LabeledContent("Token", value: tokenStatus)
            }

            Section {
                Button {
                    Task { await refreshAll() }
                } label: {
                    if isLoading {
                        ProgressView()
                    } else {
                        Label("刷新 Agent 列表", systemImage: "arrow.clockwise")
                    }
                }
                .disabled(isLoading)
            }

            Section("状态") {
                Text(serverMessage)
            }

            Section("Agent") {
                if agentUUIDs.isEmpty {
                    Text("暂无 Agent 数据。点击“刷新 Agent 列表”后会从服务器读取真实 UUID。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(agentUUIDs, id: \.self) { uuid in
                        NavigationLink {
                            AgentDetailView(server: profile, uuid: uuid)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(shortUUID(uuid))
                                    .font(.headline)
                                Text(uuid)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }

            Section {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Label("删除服务器", systemImage: "trash")
                }
            }
        }
        .navigationTitle(profile.name)
        .task {
            if agentUUIDs.isEmpty {
                await refreshAll()
            }
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

    private var tokenStatus: String {
        KeychainStore.shared.token(for: profile.id) == nil ? "未找到" : "已保存到 Keychain"
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
            serverMessage = "连接成功：\(hello)；读取到 \(uuids.count) 个 Agent。"
        } catch {
            serverMessage = "刷新失败：\(error.localizedDescription)"
        }
    }

    private func shortUUID(_ uuid: String) -> String {
        guard uuid.count > 12 else { return uuid }
        return String(uuid.prefix(8)) + "…" + String(uuid.suffix(4))
    }
}
