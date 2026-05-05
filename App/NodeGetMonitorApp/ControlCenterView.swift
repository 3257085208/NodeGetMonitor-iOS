import SwiftUI

struct ControlCenterView: View {
    @EnvironmentObject private var serverStore: ServerProfileStore

    @State private var snapshots: [AdminSnapshot] = []
    @State private var isLoading = false
    @State private var message = "主控端用于管理 NodeGet Dashboard 能力，需要更高权限的 Token。"

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView()
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        header
                        featureGrid
                        backendList
                    }
                    .padding(20)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("主控")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Task { await refresh() } } label: {
                        if isLoading { ProgressView() } else { Image(systemName: "arrow.clockwise") }
                    }
                }
            }
            .task { await refresh() }
            .refreshable { await refresh() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("主控端")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(Color.ngText)
            Text(message)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.ngMuted)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                DashboardPill(title: "主控", value: "\(serverStore.servers.count)")
                DashboardPill(title: "Agent", value: "\(snapshots.reduce(0) { $0 + $1.agentCount })", active: false)
                DashboardPill(title: "Token", value: "\(snapshots.compactMap { $0.tokenCount }.reduce(0, +))", active: false)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var featureGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            AdminFeatureCard(icon: "server.rack", title: "节点管理", subtitle: "Agent、主机名、metadata")
            AdminFeatureCard(icon: "key.horizontal", title: "Token", subtitle: "读取 Token 列表")
            AdminFeatureCard(icon: "clock.arrow.circlepath", title: "定时任务", subtitle: "Crontab / Ping / 执行")
            AdminFeatureCard(icon: "curlybraces.square", title: "KV", subtitle: "Namespace 与配置")
            AdminFeatureCard(icon: "terminal", title: "脚本 / Worker", subtitle: "JS Runtime 与脚本库")
            AdminFeatureCard(icon: "bolt.rectangle", title: "批量执行", subtitle: "后续接入安全确认")
        }
    }

    private var backendList: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionCaption(text: "已接入主控")

            if serverStore.servers.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("还没有主控")
                        .font(.title3.weight(.black))
                    Text("到设置页添加 NodeGet Server 后，这里会显示主控端管理入口。")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.ngMuted)
                }
                .padding(18)
                .ngSoftCard()
            } else if snapshots.isEmpty && isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(30)
                    .ngSoftCard()
            } else {
                ForEach(serverStore.servers) { server in
                    AdminBackendCard(server: server, snapshot: snapshot(for: server))
                }
            }
        }
    }

    private func snapshot(for server: ServerProfile) -> AdminSnapshot? {
        snapshots.first { $0.server.id == server.id }
    }

    @MainActor
    private func refresh() async {
        guard !serverStore.servers.isEmpty else {
            snapshots = []
            message = "请先在设置页添加主控。"
            return
        }

        isLoading = true
        defer { isLoading = false }

        var output: [AdminSnapshot] = []
        for server in serverStore.servers {
            let token = KeychainStore.shared.token(for: server.id) ?? ""
            let client = NodeGetClient(baseURL: server.baseURL)
            var snapshot = AdminSnapshot(server: server)

            do {
                snapshot.hello = try await client.hello()
                snapshot.serverUUID = try? await client.serverUUID()
                snapshot.version = try? await client.serverVersion()

                let uuids = try await client.listAllAgentUUIDs(token: token)
                snapshot.agentCount = uuids.count
                snapshot.agentUUIDs = uuids.sorted()

                if let tokens = try? await client.listTokens(token: token) {
                    snapshot.tokenCount = tokens.count
                }
                if let crons = try? await client.listCrontabs(token: token) {
                    snapshot.cronCount = crons.count
                }
                if let namespaces = try? await client.listKVNamespaces(token: token) {
                    snapshot.namespaceCount = namespaces.count
                }
                if let workers = try? await client.listJSWorkers(token: token) {
                    snapshot.workerCount = workers.count
                }
                snapshot.message = "在线"
            } catch {
                snapshot.message = "读取失败：\(error.localizedDescription)"
            }

            output.append(snapshot)
        }

        snapshots = output
        let okCount = output.filter { $0.message == "在线" }.count
        message = "已读取 \(okCount)/\(serverStore.servers.count) 个主控。部分功能需要 SuperToken 或管理权限。"
    }
}

struct AdminSnapshot: Identifiable, Equatable {
    var id: UUID { server.id }
    let server: ServerProfile
    var hello: String = ""
    var serverUUID: String?
    var version: String?
    var agentCount: Int = 0
    var agentUUIDs: [String] = []
    var tokenCount: Int?
    var cronCount: Int?
    var namespaceCount: Int?
    var workerCount: Int?
    var message: String = "尚未读取"
}

struct AdminFeatureCard: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.title2.weight(.bold))
                .foregroundStyle(Color.ngPrimary)
                .frame(width: 42, height: 42)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.ngPrimarySoft))
            Text(title)
                .font(.headline.weight(.black))
                .foregroundStyle(Color.ngText)
            Text(subtitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.ngMuted)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .ngSoftCard()
    }
}

struct AdminBackendCard: View {
    let server: ServerProfile
    let snapshot: AdminSnapshot?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(server.name)
                        .font(.title3.weight(.black))
                        .foregroundStyle(Color.ngText)
                    Text(server.baseURL.absoluteString)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.ngMuted)
                        .lineLimit(1)
                }
                Spacer()
                statusBadge
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                AdminMiniMetric(title: "Agent", value: "\(snapshot?.agentCount ?? 0)")
                AdminMiniMetric(title: "Token", value: value(snapshot?.tokenCount))
                AdminMiniMetric(title: "Cron", value: value(snapshot?.cronCount))
                AdminMiniMetric(title: "KV", value: value(snapshot?.namespaceCount))
                AdminMiniMetric(title: "Worker", value: value(snapshot?.workerCount))
                AdminMiniMetric(title: "版本", value: snapshot?.version ?? "--")
            }

            HStack(spacing: 10) {
                NavigationLink { AdminAgentManageView(server: server) } label: { AdminOpenButton(title: "节点") }
                NavigationLink { AdminTokenListView(server: server) } label: { AdminOpenButton(title: "Token") }
                NavigationLink { AdminCronListView(server: server) } label: { AdminOpenButton(title: "Cron") }
            }

            HStack(spacing: 10) {
                NavigationLink { AdminKVNamespaceView(server: server) } label: { AdminOpenButton(title: "KV") }
                NavigationLink { AdminWorkersView(server: server) } label: { AdminOpenButton(title: "Worker") }
            }

            Text(snapshot?.message ?? "尚未读取")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.ngMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .ngSoftCard()
    }

    private var statusBadge: some View {
        let ok = snapshot?.message == "在线"
        return Text(ok ? "在线" : "检查中")
            .font(.caption.weight(.black))
            .foregroundStyle(ok ? Color.ngPrimary : Color.ngMuted)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill((ok ? Color.ngPrimary : Color.ngMuted).opacity(0.13)))
    }

    private func value(_ value: Int?) -> String { value.map(String.init) ?? "--" }
}

struct AdminMiniMetric: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(Color.ngMuted)
            Text(value)
                .font(.headline.weight(.black))
                .foregroundStyle(Color.ngText)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.ngBackground.opacity(0.8)))
    }
}

struct AdminOpenButton: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.caption.weight(.black))
            .foregroundStyle(Color.ngPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(Capsule().fill(Color.ngPrimarySoft))
    }
}

struct AdminAgentManageView: View {
    let server: ServerProfile

    @State private var rows: [AdminAgentRow] = []
    @State private var isLoading = false
    @State private var message = "正在读取节点…"
    @State private var searchText = ""

    var body: some View {
        AdminListPage(title: "节点管理", message: message, loading: isLoading) {
            ForEach(filteredRows) { row in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(row.displayName)
                            .font(.headline.weight(.black))
                            .foregroundStyle(Color.ngText)
                        Spacer()
                        if !row.region.isEmpty {
                            Text(row.region.uppercased())
                                .font(.caption.weight(.black))
                                .foregroundStyle(Color.ngMuted)
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(Capsule().fill(Color.ngBackground))
                        }
                    }
                    Text(row.uuid)
                        .font(.caption.monospaced())
                        .foregroundStyle(Color.ngMuted)
                        .lineLimit(1)
                    Text(row.systemLine.isEmpty ? "--" : row.systemLine)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.ngMuted)
                }
                .padding(16)
                .ngSoftCard()
            }
        }
        .searchable(text: $searchText, prompt: "搜索节点…")
        .task { await load() }
        .refreshable { await load() }
    }

    private var filteredRows: [AdminAgentRow] {
        let sorted = rows.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return sorted }
        return sorted.filter { row in
            [row.displayName, row.uuid, row.region, row.systemLine].joined(separator: " ").localizedCaseInsensitiveContains(q)
        }
    }

    @MainActor private func load() async {
        guard let token = KeychainStore.shared.token(for: server.id) else { message = "未找到 Token"; return }
        isLoading = true
        defer { isLoading = false }
        do {
            let client = NodeGetClient(baseURL: server.baseURL)
            let uuids = try await client.listAllAgentUUIDs(token: token)
            let metas = (try? await client.metadataMap(token: token, uuids: uuids)) ?? [:]
            let statics = (try? await client.latestStaticInfoMap(token: token, uuids: uuids)) ?? [:]
            rows = uuids.map { uuid in
                AdminAgentRow(uuid: uuid, meta: metas[uuid], staticInfo: statics[uuid])
            }
            message = "读取到 \(rows.count) 个 Agent。"
        } catch {
            message = "读取失败：\(error.localizedDescription)"
        }
    }
}

struct AdminAgentRow: Identifiable {
    let uuid: String
    let meta: AgentMeta?
    let staticInfo: StaticAgentInfo?
    var id: String { uuid }
    var displayName: String { meta?.name.nilIfEmpty ?? staticInfo?.displayName ?? uuid }
    var region: String { meta?.region ?? "" }
    var systemLine: String { staticInfo?.systemLine ?? "" }
}

struct AdminTokenListView: View {
    let server: ServerProfile
    @State private var tokens: [AdminToken] = []
    @State private var isLoading = false
    @State private var message = "正在读取 Token…"

    var body: some View {
        AdminListPage(title: "Token 管理", message: message, loading: isLoading) {
            if tokens.isEmpty && !isLoading {
                AdminEmptyCard(text: "暂无 Token 或当前 Token 无管理权限。")
            }
            ForEach(tokens) { token in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(token.displayName)
                            .font(.headline.weight(.black))
                            .foregroundStyle(Color.ngText)
                        Spacer()
                        Text("v\(token.version ?? 0)")
                            .font(.caption.weight(.black))
                            .foregroundStyle(Color.ngMuted)
                    }
                    Text(token.tokenKey)
                        .font(.caption.monospaced())
                        .foregroundStyle(Color.ngMuted)
                        .lineLimit(2)
                    HStack {
                        AdminMiniMetric(title: "Limit", value: "\(token.limitCount)")
                        AdminMiniMetric(title: "开始", value: tokenTime(token.timestampFrom))
                        AdminMiniMetric(title: "结束", value: tokenTime(token.timestampTo))
                    }
                }
                .padding(16)
                .ngSoftCard()
            }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    @MainActor private func load() async {
        guard let token = KeychainStore.shared.token(for: server.id) else { message = "未找到 Token"; return }
        isLoading = true
        defer { isLoading = false }
        do {
            let client = NodeGetClient(baseURL: server.baseURL)
            tokens = try await client.listTokens(token: token).sorted { $0.displayName < $1.displayName }
            message = "读取到 \(tokens.count) 个 Token。v0.6.0 先开放只读列表，删除/创建放到后续版本。"
        } catch {
            message = "读取失败：\(error.localizedDescription)"
        }
    }

    private func tokenTime(_ value: Int64?) -> String {
        guard let value else { return "不限" }
        let date = Date(timeIntervalSince1970: TimeInterval(value > 1_000_000_000_000 ? value / 1000 : value))
        return NodeGetFormatters.date(date)
    }
}

struct AdminCronListView: View {
    let server: ServerProfile
    @State private var crons: [AdminCronRecord] = []
    @State private var isLoading = false
    @State private var message = "正在读取定时任务…"

    var body: some View {
        AdminListPage(title: "定时任务", message: message, loading: isLoading) {
            if crons.isEmpty && !isLoading { AdminEmptyCard(text: "暂无定时任务或当前 Token 无权限。") }
            ForEach(crons) { cron in
                VStack(alignment: .leading, spacing: 9) {
                    HStack {
                        Text(cron.name)
                            .font(.headline.weight(.black))
                            .foregroundStyle(Color.ngText)
                        Spacer()
                        Text(cron.statusText)
                            .font(.caption.weight(.black))
                            .foregroundStyle(cron.enable ? Color.ngPrimary : Color.ngMuted)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(Capsule().fill((cron.enable ? Color.ngPrimary : Color.ngMuted).opacity(0.13)))
                    }
                    Text(cron.cronExpression)
                        .font(.caption.monospaced())
                        .foregroundStyle(Color.ngMuted)
                    Text(cron.typeText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.ngMuted)
                }
                .padding(16)
                .ngSoftCard()
            }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    @MainActor private func load() async {
        guard let token = KeychainStore.shared.token(for: server.id) else { message = "未找到 Token"; return }
        isLoading = true
        defer { isLoading = false }
        do {
            let client = NodeGetClient(baseURL: server.baseURL)
            crons = try await client.listCrontabs(token: token).sorted { $0.id < $1.id }
            message = "读取到 \(crons.count) 个定时任务。v0.6.0 先开放只读列表。"
        } catch {
            message = "读取失败：\(error.localizedDescription)"
        }
    }
}

struct AdminKVNamespaceView: View {
    let server: ServerProfile
    @State private var namespaces: [String] = []
    @State private var isLoading = false
    @State private var message = "正在读取 KV namespace…"

    var body: some View {
        AdminListPage(title: "KV 管理", message: message, loading: isLoading) {
            if namespaces.isEmpty && !isLoading { AdminEmptyCard(text: "暂无 namespace 或当前 Token 无权限。") }
            ForEach(namespaces, id: \.self) { namespace in
                NavigationLink { AdminKVEntryView(server: server, namespace: namespace) } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(namespace)
                                .font(.headline.weight(.black))
                                .foregroundStyle(Color.ngText)
                            Text(namespace.hasPrefix("metadata") ? "Agent metadata" : "KV namespace")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.ngMuted)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(Color.ngMuted)
                    }
                    .padding(16)
                    .ngSoftCard()
                }
                .buttonStyle(.plain)
            }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    @MainActor private func load() async {
        guard let token = KeychainStore.shared.token(for: server.id) else { message = "未找到 Token"; return }
        isLoading = true
        defer { isLoading = false }
        do {
            let client = NodeGetClient(baseURL: server.baseURL)
            namespaces = try await client.listKVNamespaces(token: token).sorted()
            message = "读取到 \(namespaces.count) 个 namespace。"
        } catch {
            message = "读取失败：\(error.localizedDescription)"
        }
    }
}

struct AdminKVEntryView: View {
    let server: ServerProfile
    let namespace: String
    @State private var entries: [KVValueRow] = []
    @State private var isLoading = false
    @State private var message = "正在读取 KV…"

    var body: some View {
        AdminListPage(title: namespace, message: message, loading: isLoading) {
            if entries.isEmpty && !isLoading { AdminEmptyCard(text: "暂无 KV。") }
            ForEach(entries, id: \.key) { entry in
                VStack(alignment: .leading, spacing: 8) {
                    Text(entry.key)
                        .font(.headline.weight(.black))
                        .foregroundStyle(Color.ngText)
                    Text(entry.value?.stringValue ?? jsonPreview(entry.value))
                        .font(.caption.monospaced())
                        .foregroundStyle(Color.ngMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .ngSoftCard()
            }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    @MainActor private func load() async {
        guard let token = KeychainStore.shared.token(for: server.id) else { message = "未找到 Token"; return }
        isLoading = true
        defer { isLoading = false }
        do {
            let client = NodeGetClient(baseURL: server.baseURL)
            entries = try await client.listKVEntries(token: token, namespace: namespace).sorted { $0.key < $1.key }
            message = "读取到 \(entries.count) 个 KV。v0.6.0 先开放只读浏览。"
        } catch {
            message = "读取失败：\(error.localizedDescription)"
        }
    }

    private func jsonPreview(_ value: JSONValue?) -> String {
        guard let value else { return "null" }
        switch value {
        case .string(let s): return s
        case .number(let n): return n.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(n)) : String(n)
        case .bool(let b): return b ? "true" : "false"
        case .null: return "null"
        case .array(let items): return "Array(\(items.count))"
        case .object(let object): return "Object(\(object.count))"
        }
    }
}

struct AdminWorkersView: View {
    let server: ServerProfile
    @State private var workers: [String] = []
    @State private var scriptEntries: [KVValueRow] = []
    @State private var isLoading = false
    @State private var message = "正在读取脚本与 Worker…"

    var body: some View {
        AdminListPage(title: "脚本 / Worker", message: message, loading: isLoading) {
            SectionCaption(text: "JS Worker")
            if workers.isEmpty && !isLoading { AdminEmptyCard(text: "暂无 JS Worker。") }
            ForEach(workers, id: \.self) { worker in
                Text(worker)
                    .font(.headline.weight(.black))
                    .foregroundStyle(Color.ngText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .ngSoftCard()
            }

            SectionCaption(text: "脚本库 script_snippet")
            if scriptEntries.isEmpty && !isLoading { AdminEmptyCard(text: "暂无脚本片段。") }
            ForEach(scriptEntries, id: \.key) { entry in
                VStack(alignment: .leading, spacing: 8) {
                    Text(entry.key)
                        .font(.headline.weight(.black))
                        .foregroundStyle(Color.ngText)
                    Text(entry.value?.stringValue ?? "脚本对象")
                        .font(.caption.monospaced())
                        .foregroundStyle(Color.ngMuted)
                        .lineLimit(3)
                }
                .padding(16)
                .ngSoftCard()
            }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    @MainActor private func load() async {
        guard let token = KeychainStore.shared.token(for: server.id) else { message = "未找到 Token"; return }
        isLoading = true
        defer { isLoading = false }
        do {
            let client = NodeGetClient(baseURL: server.baseURL)
            workers = (try? await client.listJSWorkers(token: token).sorted()) ?? []
            scriptEntries = (try? await client.listKVEntries(token: token, namespace: "script_snippet").sorted { $0.key < $1.key }) ?? []
            message = "读取到 \(workers.count) 个 Worker，\(scriptEntries.count) 个脚本片段。"
        } catch {
            message = "读取失败：\(error.localizedDescription)"
        }
    }
}

struct AdminListPage<Content: View>: View {
    let title: String
    let message: String
    let loading: Bool
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            AppBackgroundView()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(title)
                            .font(.system(size: 30, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ngText)
                        Text(message)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.ngMuted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if loading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(24)
                            .ngSoftCard()
                    }
                    content()
                }
                .padding(20)
                .padding(.bottom, 32)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct AdminEmptyCard: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.ngMuted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .ngSoftCard()
    }
}
