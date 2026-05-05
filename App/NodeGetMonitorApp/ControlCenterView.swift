import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct ControlCenterView: View {
    @EnvironmentObject private var serverStore: ServerProfileStore

    @State private var snapshots: [AdminSnapshot] = []
    @State private var isLoading = false
    @State private var message = "主控端已开放创建、编辑、删除、启停、运行等操作。删除和执行类操作会二次确认。"

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
            Text("移动主控端")
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
            AdminFeatureCard(icon: "server.rack", title: "节点管理", subtitle: "Agent、metadata、主机信息")
            AdminFeatureCard(icon: "key.horizontal", title: "Token", subtitle: "创建 / 编辑权限 / 删除")
            AdminFeatureCard(icon: "clock.arrow.circlepath", title: "定时任务", subtitle: "创建 / 启停 / 编辑 / 删除")
            AdminFeatureCard(icon: "curlybraces.square", title: "KV", subtitle: "Namespace / Key / Value")
            AdminFeatureCard(icon: "terminal", title: "Worker", subtitle: "创建 / 更新 / 运行 / 删除")
            AdminFeatureCard(icon: "exclamationmark.triangle", title: "危险操作", subtitle: "全部二次确认")
        }
    }

    private var backendList: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionCaption(text: "已接入主控")

            if serverStore.servers.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("还没有主控")
                        .font(.title3.weight(.black))
                    Text("到设置页添加 NodeGet Server 后，这里会显示完整主控管理入口。")
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

                if let tokens = try? await client.listTokens(token: token) { snapshot.tokenCount = tokens.count }
                if let crons = try? await client.listCrontabs(token: token) { snapshot.cronCount = crons.count }
                if let namespaces = try? await client.listKVNamespaces(token: token) { snapshot.namespaceCount = namespaces.count }
                if let workers = try? await client.listJSWorkers(token: token) { snapshot.workerCount = workers.count }
                snapshot.message = "在线"
            } catch {
                snapshot.message = "读取失败：\(error.localizedDescription)"
            }

            output.append(snapshot)
        }

        snapshots = output
        let okCount = output.filter { $0.message == "在线" }.count
        message = "已读取 \(okCount)/\(serverStore.servers.count) 个主控。当前版本支持写操作，请谨慎使用删除和执行。"
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
                        if !row.region.isEmpty { AdminSmallBadge(row.region.uppercased()) }
                    }
                    Text(row.uuid).font(.caption.monospaced()).foregroundStyle(Color.ngMuted).lineLimit(1)
                    Text(row.systemLine.isEmpty ? "--" : row.systemLine)
                        .font(.caption.weight(.semibold)).foregroundStyle(Color.ngMuted)
                    NavigationLink { AdminAgentMetadataEditorView(server: server, row: row) } label: { AdminActionCapsule(title: "编辑 metadata", icon: "pencil") }
                    .buttonStyle(.plain)
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
        return sorted.filter { row in [row.displayName, row.uuid, row.region, row.systemLine].joined(separator: " ").localizedCaseInsensitiveContains(q) }
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
            rows = uuids.map { uuid in AdminAgentRow(uuid: uuid, meta: metas[uuid], staticInfo: statics[uuid]) }
            message = "读取到 \(rows.count) 个 Agent。"
        } catch { message = "读取失败：\(error.localizedDescription)" }
    }
}

struct AdminAgentRow: Identifiable, Equatable {
    let uuid: String
    let meta: AgentMeta?
    let staticInfo: StaticAgentInfo?
    var id: String { uuid }
    var displayName: String { meta?.name.nilIfEmpty ?? staticInfo?.displayName ?? uuid }
    var region: String { meta?.region ?? "" }
    var systemLine: String { staticInfo?.systemLine ?? "" }
}

struct AdminAgentMetadataEditorView: View {
    let server: ServerProfile
    let row: AdminAgentRow
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var region: String
    @State private var price: String
    @State private var priceUnit: String
    @State private var priceCycle: String
    @State private var expireTime: String
    @State private var message = "修改后会写入 Agent UUID namespace 下的 metadata_* KV。"
    @State private var isSaving = false

    init(server: ServerProfile, row: AdminAgentRow) {
        self.server = server
        self.row = row
        _name = State(initialValue: row.meta?.name ?? "")
        _region = State(initialValue: row.meta?.region ?? "")
        _price = State(initialValue: row.meta.map { $0.price > 0 ? String($0.price) : "" } ?? "")
        _priceUnit = State(initialValue: row.meta?.priceUnit ?? "USD")
        _priceCycle = State(initialValue: row.meta.map { String($0.priceCycle) } ?? "365")
        _expireTime = State(initialValue: row.meta?.expireTime ?? "")
    }

    var body: some View {
        AdminFormPage(title: "编辑节点 metadata", message: message, saving: isSaving) {
            AdminTextField(title: "显示名称", text: $name)
            AdminTextField(title: "地区", text: $region)
            AdminTextField(title: "价格", text: $price, keyboard: .decimalPad)
            AdminTextField(title: "币种", text: $priceUnit)
            AdminTextField(title: "计费周期 / 天", text: $priceCycle, keyboard: .numberPad)
            AdminTextField(title: "到期时间", text: $expireTime, keyboard: .numbersAndPunctuation)
            Button { Task { await save() } } label: { AdminPrimaryButtonLabel(title: "保存 metadata", icon: "square.and.arrow.down") }
        }
    }

    @MainActor private func save() async {
        guard let token = KeychainStore.shared.token(for: server.id) else { message = "未找到 Token"; return }
        isSaving = true
        defer { isSaving = false }
        do {
            let client = NodeGetClient(baseURL: server.baseURL)
            let values: [(String, JSONValue)] = [
                ("metadata_name", .string(name)),
                ("metadata_region", .string(region)),
                ("metadata_price", .number(Double(price) ?? 0)),
                ("metadata_price_unit", .string(priceUnit)),
                ("metadata_price_cycle", .number(Double(priceCycle) ?? 0)),
                ("metadata_expire_time", .string(expireTime))
            ]
            for (key, value) in values { _ = try await client.setKVValue(token: token, namespace: row.uuid, key: key, value: value) }
            message = "保存成功。"
            dismiss()
        } catch { message = "保存失败：\(error.localizedDescription)" }
    }
}

struct AdminTokenListView: View {
    let server: ServerProfile
    @State private var tokens: [AdminToken] = []
    @State private var isLoading = false
    @State private var message = "正在读取 Token…"
    @State private var showingCreate = false
    @State private var editToken: AdminToken?
    @State private var deletingTokenKey: String?
    @State private var showDeleteAlert = false

    var body: some View {
        AdminListPage(title: "Token 管理", message: message, loading: isLoading) {
            if tokens.isEmpty && !isLoading { AdminEmptyCard(text: "暂无 Token 或当前 Token 无管理权限。") }
            ForEach(tokens) { token in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(token.displayName).font(.headline.weight(.black)).foregroundStyle(Color.ngText)
                        Spacer()
                        Text("v\(token.version ?? 0)").font(.caption.weight(.black)).foregroundStyle(Color.ngMuted)
                    }
                    Text(token.tokenKey).font(.caption.monospaced()).foregroundStyle(Color.ngMuted).lineLimit(2)
                    HStack {
                        AdminMiniMetric(title: "Limit", value: "\(token.limitCount)")
                        AdminMiniMetric(title: "开始", value: tokenTime(token.timestampFrom))
                        AdminMiniMetric(title: "结束", value: tokenTime(token.timestampTo))
                    }
                    HStack(spacing: 10) {
                        Button { copy(token.tokenKey) } label: { AdminActionCapsule(title: "复制 Key", icon: "doc.on.doc") }
                        Button { editToken = token } label: { AdminActionCapsule(title: "编辑权限", icon: "pencil") }
                        Button(role: .destructive) {
                            deletingTokenKey = token.tokenKey; showDeleteAlert = true
                        } label: { AdminDangerCapsule(title: "删除", icon: "trash") }
                    }
                }
                .padding(16)
                .ngSoftCard()
            }
        }
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showingCreate = true } label: { Image(systemName: "plus") } } }
        .sheet(isPresented: $showingCreate) { AdminTokenCreateSheet(server: server) { Task { await load() } } }
        .sheet(item: $editToken) { token in AdminTokenEditSheet(server: server, token: token) { Task { await load() } } }
        .alert("确定删除 Token？", isPresented: $showDeleteAlert) {
            Button("删除", role: .destructive) { Task { await deleteSelectedToken() } }
            Button("取消", role: .cancel) {}
        } message: { Text("目标：\(deletingTokenKey ?? "")。SuperToken 会被服务端保护，但普通 Token 会被删除。") }
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
            message = "读取到 \(tokens.count) 个 Token。支持创建、编辑权限、删除。"
        } catch { message = "读取失败：\(error.localizedDescription)" }
    }

    @MainActor private func deleteSelectedToken() async {
        guard let token = KeychainStore.shared.token(for: server.id), let target = deletingTokenKey else { return }
        do {
            let client = NodeGetClient(baseURL: server.baseURL)
            _ = try await client.deleteToken(token: token, targetToken: target)
            message = "已删除 Token：\(target)"
            await load()
        } catch { message = "删除失败：\(error.localizedDescription)" }
    }

    private func tokenTime(_ value: Int64?) -> String {
        guard let value else { return "不限" }
        let date = Date(timeIntervalSince1970: TimeInterval(value > 1_000_000_000_000 ? value / 1000 : value))
        return NodeGetFormatters.date(date)
    }

    private func copy(_ text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #endif
    }
}

struct AdminTokenCreateSheet: View {
    let server: ServerProfile
    let onDone: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var username = ""
    @State private var password = ""
    @State private var tokenLimitText = AdminJSONCodec.pretty(JSONValue.array([.object(["scopes": .array([.string("global")]), "permissions": .array([])])]))
    @State private var resultToken = ""
    @State private var message = "默认创建 Global scope。权限 JSON 可按 NodeGet Dashboard 导出的 token_limit 调整。"
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            AdminFormPage(title: "创建 Token", message: message, saving: isSaving) {
                AdminTextField(title: "用户名（可选）", text: $username)
                AdminTextField(title: "密码（可选，和用户名同时使用）", text: $password)
                AdminJSONEditor(title: "token_limit JSON", text: $tokenLimitText)
                if !resultToken.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("新 Token：").font(.headline)
                        Text(resultToken).font(.caption.monospaced()).foregroundStyle(Color.ngMuted).textSelection(.enabled)
                        Button { copy(resultToken) } label: { AdminActionCapsule(title: "复制完整 Token", icon: "doc.on.doc") }
                    }.padding(14).ngSoftCard()
                }
                Button { Task { await create() } } label: { AdminPrimaryButtonLabel(title: "创建 Token", icon: "plus.circle") }
            }
            .navigationTitle("创建 Token")
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("关闭") { dismiss() } } }
        }
    }

    @MainActor private func create() async {
        guard let father = KeychainStore.shared.token(for: server.id) else { message = "未找到 Token"; return }
        do {
            isSaving = true
            defer { isSaving = false }
            guard case .array(let limits) = try AdminJSONCodec.parse(tokenLimitText) else { message = "token_limit 必须是数组"; return }
            let client = NodeGetClient(baseURL: server.baseURL)
            let res = try await client.createToken(fatherToken: father, username: username, password: password, tokenLimit: limits)
            resultToken = res.fullToken
            message = "创建成功，请立即复制 secret；列表接口不会再次返回 secret。"
            onDone()
        } catch { message = "创建失败：\(error.localizedDescription)" }
    }
    private func copy(_ text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #endif
    }
}

struct AdminTokenEditSheet: View {
    let server: ServerProfile
    let token: AdminToken
    let onDone: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var rawLimit: String
    @State private var message = "编辑会覆盖目标 Token 的 token_limit。"
    @State private var isSaving = false

    init(server: ServerProfile, token: AdminToken, onDone: @escaping () -> Void) {
        self.server = server
        self.token = token
        self.onDone = onDone
        _rawLimit = State(initialValue: AdminJSONCodec.pretty(.array(token.tokenLimit)))
    }

    var body: some View {
        NavigationStack {
            AdminFormPage(title: "编辑 Token 权限", message: message, saving: isSaving) {
                Text(token.tokenKey).font(.caption.monospaced()).foregroundStyle(Color.ngMuted).padding(12).ngSoftCard()
                AdminJSONEditor(title: "新的 token_limit JSON", text: $rawLimit)
                Button { Task { await save() } } label: { AdminPrimaryButtonLabel(title: "保存权限", icon: "square.and.arrow.down") }
            }
            .navigationTitle("编辑权限")
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("关闭") { dismiss() } } }
        }
    }

    @MainActor private func save() async {
        guard let superToken = KeychainStore.shared.token(for: server.id) else { message = "未找到 Token"; return }
        do {
            isSaving = true
            defer { isSaving = false }
            guard case .array(let limits) = try AdminJSONCodec.parse(rawLimit) else { message = "token_limit 必须是数组"; return }
            let client = NodeGetClient(baseURL: server.baseURL)
            _ = try await client.editTokenLimit(token: superToken, targetToken: token.tokenKey, limit: limits)
            message = "保存成功。"
            onDone()
            dismiss()
        } catch { message = "保存失败：\(error.localizedDescription)" }
    }
}

struct AdminCronListView: View {
    let server: ServerProfile
    @State private var crons: [AdminCronRecord] = []
    @State private var isLoading = false
    @State private var message = "正在读取定时任务…"
    @State private var showingCreate = false
    @State private var editingCron: AdminCronRecord?
    @State private var deletingName: String?
    @State private var showDeleteAlert = false

    var body: some View {
        AdminListPage(title: "定时任务", message: message, loading: isLoading) {
            if crons.isEmpty && !isLoading { AdminEmptyCard(text: "暂无定时任务或当前 Token 无权限。") }
            ForEach(crons) { cron in
                VStack(alignment: .leading, spacing: 9) {
                    HStack {
                        Text(cron.name).font(.headline.weight(.black)).foregroundStyle(Color.ngText)
                        Spacer()
                        AdminSmallBadge(cron.statusText)
                    }
                    Text(cron.cronExpression).font(.caption.monospaced()).foregroundStyle(Color.ngMuted)
                    Text(cron.typeText).font(.caption.weight(.semibold)).foregroundStyle(Color.ngMuted)
                    HStack(spacing: 10) {
                        Button { Task { await setEnable(cron) } } label: { AdminActionCapsule(title: cron.enable ? "停用" : "启用", icon: cron.enable ? "pause.circle" : "play.circle") }
                        Button { editingCron = cron } label: { AdminActionCapsule(title: "编辑", icon: "pencil") }
                        Button(role: .destructive) { deletingName = cron.name; showDeleteAlert = true } label: { AdminDangerCapsule(title: "删除", icon: "trash") }
                    }
                }.padding(16).ngSoftCard()
            }
        }
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showingCreate = true } label: { Image(systemName: "plus") } } }
        .sheet(isPresented: $showingCreate) { AdminCronEditorSheet(server: server, cron: nil) { Task { await load() } } }
        .sheet(item: $editingCron) { cron in AdminCronEditorSheet(server: server, cron: cron) { Task { await load() } } }
        .alert("确定删除定时任务？", isPresented: $showDeleteAlert) {
            Button("删除", role: .destructive) { Task { await deleteSelected() } }
            Button("取消", role: .cancel) {}
        } message: { Text(deletingName ?? "") }
        .task { await load() }
        .refreshable { await load() }
    }

    @MainActor private func load() async {
        guard let token = KeychainStore.shared.token(for: server.id) else { message = "未找到 Token"; return }
        isLoading = true; defer { isLoading = false }
        do {
            let client = NodeGetClient(baseURL: server.baseURL)
            crons = try await client.listCrontabs(token: token).sorted { $0.id < $1.id }
            message = "读取到 \(crons.count) 个定时任务。支持创建、启停、编辑、删除。"
        } catch { message = "读取失败：\(error.localizedDescription)" }
    }

    @MainActor private func setEnable(_ cron: AdminCronRecord) async {
        guard let token = KeychainStore.shared.token(for: server.id) else { return }
        do { _ = try await NodeGetClient(baseURL: server.baseURL).setCrontabEnable(token: token, name: cron.name, enable: !cron.enable); await load() }
        catch { message = "操作失败：\(error.localizedDescription)" }
    }

    @MainActor private func deleteSelected() async {
        guard let token = KeychainStore.shared.token(for: server.id), let name = deletingName else { return }
        do { _ = try await NodeGetClient(baseURL: server.baseURL).deleteCrontab(token: token, name: name); await load() }
        catch { message = "删除失败：\(error.localizedDescription)" }
    }
}

struct AdminCronEditorSheet: View {
    let server: ServerProfile
    let cron: AdminCronRecord?
    let onDone: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var expression: String
    @State private var cronTypeText: String
    @State private var message = "cron_type 使用 JSON。Agent ping 示例已预填，可改成 tcp_ping / execute / server.js_worker。"
    @State private var isSaving = false

    init(server: ServerProfile, cron: AdminCronRecord?, onDone: @escaping () -> Void) {
        self.server = server; self.cron = cron; self.onDone = onDone
        _name = State(initialValue: cron?.name ?? "")
        _expression = State(initialValue: cron?.cronExpression ?? "0 */5 * * * *")
        let defaultType = JSONValue.object(["agent": .array([.array([]), .object(["task": .object(["ping": .string("1.1.1.1")])])])])
        _cronTypeText = State(initialValue: cron?.cronType.map { AdminJSONCodec.pretty($0) } ?? AdminJSONCodec.pretty(defaultType))
    }
    var body: some View {
        NavigationStack {
            AdminFormPage(title: cron == nil ? "创建定时任务" : "编辑定时任务", message: message, saving: isSaving) {
                AdminTextField(title: "名称", text: $name)
                AdminTextField(title: "Cron 表达式", text: $expression)
                AdminJSONEditor(title: "cron_type JSON", text: $cronTypeText)
                Button { Task { await save() } } label: { AdminPrimaryButtonLabel(title: cron == nil ? "创建" : "保存", icon: "clock.arrow.circlepath") }
            }
            .navigationTitle(cron == nil ? "创建 Cron" : "编辑 Cron")
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("关闭") { dismiss() } } }
        }
    }
    @MainActor private func save() async {
        guard let token = KeychainStore.shared.token(for: server.id) else { message = "未找到 Token"; return }
        do {
            isSaving = true; defer { isSaving = false }
            let cronType = try AdminJSONCodec.parse(cronTypeText)
            let client = NodeGetClient(baseURL: server.baseURL)
            if cron == nil { _ = try await client.createCrontab(token: token, name: name, cronExpression: expression, cronType: cronType) }
            else { _ = try await client.editCrontab(token: token, name: name, cronExpression: expression, cronType: cronType) }
            onDone(); dismiss()
        } catch { message = "保存失败：\(error.localizedDescription)" }
    }
}

struct AdminKVNamespaceView: View {
    let server: ServerProfile
    @State private var namespaces: [String] = []
    @State private var isLoading = false
    @State private var message = "正在读取 KV namespace…"
    @State private var showingCreate = false
    @State private var newNamespace = ""
    @State private var deletingNamespace: String?
    @State private var showDeleteAlert = false

    var body: some View {
        AdminListPage(title: "KV 管理", message: message, loading: isLoading) {
            if namespaces.isEmpty && !isLoading { AdminEmptyCard(text: "暂无 namespace 或当前 Token 无权限。") }
            ForEach(namespaces, id: \.self) { namespace in
                HStack {
                    NavigationLink { AdminKVEntryView(server: server, namespace: namespace) } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(namespace).font(.headline.weight(.black)).foregroundStyle(Color.ngText)
                            Text("KV namespace").font(.caption.weight(.semibold)).foregroundStyle(Color.ngMuted)
                        }
                    }.buttonStyle(.plain)
                    Spacer()
                    Button(role: .destructive) { deletingNamespace = namespace; showDeleteAlert = true } label: { Image(systemName: "trash") }
                }.padding(16).ngSoftCard()
            }
        }
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showingCreate = true } label: { Image(systemName: "plus") } } }
        .alert("创建 Namespace", isPresented: $showingCreate) {
            TextField("namespace", text: $newNamespace)
            Button("创建") { Task { await createNamespace() } }
            Button("取消", role: .cancel) {}
        }
        .alert("确定删除整个 Namespace？", isPresented: $showDeleteAlert) {
            Button("删除", role: .destructive) { Task { await deleteNamespace() } }
            Button("取消", role: .cancel) {}
        } message: { Text("会删除该 Namespace 下全部 KV：\(deletingNamespace ?? "")") }
        .task { await load() }
        .refreshable { await load() }
    }
    @MainActor private func load() async {
        guard let token = KeychainStore.shared.token(for: server.id) else { message = "未找到 Token"; return }
        isLoading = true; defer { isLoading = false }
        do { namespaces = try await NodeGetClient(baseURL: server.baseURL).listKVNamespaces(token: token).sorted(); message = "读取到 \(namespaces.count) 个 namespace。" }
        catch { message = "读取失败：\(error.localizedDescription)" }
    }
    @MainActor private func createNamespace() async {
        guard let token = KeychainStore.shared.token(for: server.id) else { return }
        do { _ = try await NodeGetClient(baseURL: server.baseURL).createKVNamespace(token: token, namespace: newNamespace); newNamespace = ""; await load() }
        catch { message = "创建失败：\(error.localizedDescription)" }
    }
    @MainActor private func deleteNamespace() async {
        guard let token = KeychainStore.shared.token(for: server.id), let ns = deletingNamespace else { return }
        do { _ = try await NodeGetClient(baseURL: server.baseURL).deleteKVNamespace(token: token, namespace: ns); await load() }
        catch { message = "删除失败：\(error.localizedDescription)" }
    }
}

struct AdminKVEntryView: View {
    let server: ServerProfile
    let namespace: String
    @State private var entries: [KVValueRow] = []
    @State private var isLoading = false
    @State private var message = "正在读取 KV…"
    @State private var showingSet = false
    @State private var editingEntry: KVValueRow?
    @State private var deletingKey: String?
    @State private var showDeleteAlert = false

    var body: some View {
        AdminListPage(title: namespace, message: message, loading: isLoading) {
            if entries.isEmpty && !isLoading { AdminEmptyCard(text: "暂无 KV。") }
            ForEach(entries, id: \.key) { entry in
                VStack(alignment: .leading, spacing: 8) {
                    Text(entry.key).font(.headline.weight(.black)).foregroundStyle(Color.ngText)
                    Text(AdminJSONCodec.pretty(entry.value ?? .null)).font(.caption.monospaced()).foregroundStyle(Color.ngMuted).lineLimit(4)
                    HStack(spacing: 10) {
                        Button { editingEntry = entry } label: { AdminActionCapsule(title: "编辑", icon: "pencil") }
                        Button(role: .destructive) { deletingKey = entry.key; showDeleteAlert = true } label: { AdminDangerCapsule(title: "删除", icon: "trash") }
                    }
                }.padding(16).ngSoftCard()
            }
        }
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showingSet = true } label: { Image(systemName: "plus") } } }
        .sheet(isPresented: $showingSet) { AdminKVSetSheet(server: server, namespace: namespace, entry: nil) { Task { await load() } } }
        .sheet(item: $editingEntry) { entry in AdminKVSetSheet(server: server, namespace: namespace, entry: entry) { Task { await load() } } }
        .alert("确定删除 Key？", isPresented: $showDeleteAlert) {
            Button("删除", role: .destructive) { Task { await deleteKey() } }
            Button("取消", role: .cancel) {}
        } message: { Text(deletingKey ?? "") }
        .task { await load() }
        .refreshable { await load() }
    }
    @MainActor private func load() async {
        guard let token = KeychainStore.shared.token(for: server.id) else { message = "未找到 Token"; return }
        isLoading = true; defer { isLoading = false }
        do { entries = try await NodeGetClient(baseURL: server.baseURL).listKVEntries(token: token, namespace: namespace).sorted { $0.key < $1.key }; message = "读取到 \(entries.count) 个 KV。支持新增、编辑、删除。" }
        catch { message = "读取失败：\(error.localizedDescription)" }
    }
    @MainActor private func deleteKey() async {
        guard let token = KeychainStore.shared.token(for: server.id), let key = deletingKey else { return }
        do { _ = try await NodeGetClient(baseURL: server.baseURL).deleteKVKey(token: token, namespace: namespace, key: key); await load() }
        catch { message = "删除失败：\(error.localizedDescription)" }
    }
}

struct AdminKVSetSheet: View {
    let server: ServerProfile
    let namespace: String
    let entry: KVValueRow?
    let onDone: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var key: String
    @State private var valueText: String
    @State private var message = "value 必须是合法 JSON，例如字符串需要写成 \"hello\"。"
    @State private var isSaving = false
    init(server: ServerProfile, namespace: String, entry: KVValueRow?, onDone: @escaping () -> Void) {
        self.server = server; self.namespace = namespace; self.entry = entry; self.onDone = onDone
        _key = State(initialValue: entry?.key ?? "")
        _valueText = State(initialValue: AdminJSONCodec.pretty(entry?.value ?? .string("")))
    }
    var body: some View {
        NavigationStack {
            AdminFormPage(title: entry == nil ? "新增 KV" : "编辑 KV", message: message, saving: isSaving) {
                AdminTextField(title: "Key", text: $key)
                AdminJSONEditor(title: "Value JSON", text: $valueText)
                Button { Task { await save() } } label: { AdminPrimaryButtonLabel(title: "保存 KV", icon: "square.and.arrow.down") }
            }
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("关闭") { dismiss() } } }
        }
    }
    @MainActor private func save() async {
        guard let token = KeychainStore.shared.token(for: server.id) else { message = "未找到 Token"; return }
        do {
            isSaving = true; defer { isSaving = false }
            let value = try AdminJSONCodec.parse(valueText)
            _ = try await NodeGetClient(baseURL: server.baseURL).setKVValue(token: token, namespace: namespace, key: key, value: value)
            onDone(); dismiss()
        } catch { message = "保存失败：\(error.localizedDescription)" }
    }
}

struct AdminWorkersView: View {
    let server: ServerProfile
    @State private var workers: [String] = []
    @State private var scriptEntries: [KVValueRow] = []
    @State private var isLoading = false
    @State private var message = "正在读取脚本与 Worker…"
    @State private var showingCreate = false
    @State private var editingName = ""
    @State private var showEditWorker = false
    @State private var deletingName: String?
    @State private var showDeleteAlert = false

    var body: some View {
        AdminListPage(title: "脚本 / Worker", message: message, loading: isLoading) {
            SectionCaption(text: "JS Worker")
            if workers.isEmpty && !isLoading { AdminEmptyCard(text: "暂无 JS Worker。") }
            ForEach(workers, id: \.self) { worker in
                VStack(alignment: .leading, spacing: 10) {
                    Text(worker).font(.headline.weight(.black)).foregroundStyle(Color.ngText)
                    HStack(spacing: 10) {
                        Button { editingName = worker; showEditWorker = true } label: { AdminActionCapsule(title: "编辑", icon: "pencil") }
                        Button { Task { await run(worker) } } label: { AdminActionCapsule(title: "运行", icon: "play.circle") }
                        Button(role: .destructive) { deletingName = worker; showDeleteAlert = true } label: { AdminDangerCapsule(title: "删除", icon: "trash") }
                    }
                }.frame(maxWidth: .infinity, alignment: .leading).padding(16).ngSoftCard()
            }
            SectionCaption(text: "脚本库 script_snippet")
            ForEach(scriptEntries, id: \.key) { entry in
                VStack(alignment: .leading, spacing: 8) {
                    Text(entry.key).font(.headline.weight(.black)).foregroundStyle(Color.ngText)
                    Text(entry.value?.stringValue ?? "脚本对象").font(.caption.monospaced()).foregroundStyle(Color.ngMuted).lineLimit(3)
                }.padding(16).ngSoftCard()
            }
        }
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { showingCreate = true } label: { Image(systemName: "plus") } } }
        .sheet(isPresented: $showingCreate) { AdminWorkerEditorSheet(server: server, workerName: nil) { Task { await load() } } }
        .sheet(isPresented: $showEditWorker) { AdminWorkerEditorSheet(server: server, workerName: editingName) { Task { await load() } } }
        .alert("确定删除 Worker？", isPresented: $showDeleteAlert) {
            Button("删除", role: .destructive) { Task { await deleteSelected() } }
            Button("取消", role: .cancel) {}
        } message: { Text(deletingName ?? "") }
        .task { await load() }
        .refreshable { await load() }
    }
    @MainActor private func load() async {
        guard let token = KeychainStore.shared.token(for: server.id) else { message = "未找到 Token"; return }
        isLoading = true; defer { isLoading = false }
        do {
            let client = NodeGetClient(baseURL: server.baseURL)
            workers = (try? await client.listJSWorkers(token: token).sorted()) ?? []
            scriptEntries = (try? await client.listKVEntries(token: token, namespace: "script_snippet").sorted { $0.key < $1.key }) ?? []
            message = "读取到 \(workers.count) 个 Worker，\(scriptEntries.count) 个脚本片段。支持创建、更新、运行、删除。"
        } catch { message = "读取失败：\(error.localizedDescription)" }
    }
    @MainActor private func run(_ name: String) async {
        guard let token = KeychainStore.shared.token(for: server.id) else { return }
        do { let id = try await NodeGetClient(baseURL: server.baseURL).runJSWorker(token: token, name: name, params: .object([:])); message = "已触发 Worker：\(name)，结果 ID：\(id.id)" }
        catch { message = "运行失败：\(error.localizedDescription)" }
    }
    @MainActor private func deleteSelected() async {
        guard let token = KeychainStore.shared.token(for: server.id), let name = deletingName else { return }
        do { _ = try await NodeGetClient(baseURL: server.baseURL).deleteJSWorker(token: token, name: name); await load() }
        catch { message = "删除失败：\(error.localizedDescription)" }
    }
}

struct AdminWorkerEditorSheet: View {
    let server: ServerProfile
    let workerName: String?
    let onDone: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var description = ""
    @State private var routeName = ""
    @State private var runtimeCleanTime = "60000"
    @State private var script = "export default {\n  async onCall(params, env, ctx) {\n    return { ok: true, params, env };\n  }\n};"
    @State private var envText = "{}"
    @State private var message = "JS 会自动 base64 后提交。"
    @State private var isSaving = false
    var body: some View {
        NavigationStack {
            AdminFormPage(title: workerName == nil ? "创建 Worker" : "编辑 Worker", message: message, saving: isSaving) {
                AdminTextField(title: "名称", text: $name)
                AdminTextField(title: "描述", text: $description)
                AdminTextField(title: "Route 名称（可选）", text: $routeName)
                AdminTextField(title: "Runtime 清理时间 ms", text: $runtimeCleanTime, keyboard: .numberPad)
                AdminJSONEditor(title: "Env JSON", text: $envText)
                VStack(alignment: .leading, spacing: 8) {
                    Text("JS 脚本").font(.headline).foregroundStyle(Color.ngMuted)
                    TextEditor(text: $script).font(.caption.monospaced()).frame(minHeight: 240).padding(8).background(RoundedRectangle(cornerRadius: 16).fill(Color.white))
                }
                Button { Task { await save() } } label: { AdminPrimaryButtonLabel(title: workerName == nil ? "创建 Worker" : "保存 Worker", icon: "terminal") }
            }
            .toolbar { ToolbarItem(placement: .topBarLeading) { Button("关闭") { dismiss() } } }
            .task { await loadExisting() }
        }
    }
    @MainActor private func loadExisting() async {
        guard let workerName, let token = KeychainStore.shared.token(for: server.id) else { return }
        do {
            let record = try await NodeGetClient(baseURL: server.baseURL).readJSWorker(token: token, name: workerName)
            name = record.name; description = record.description ?? ""; routeName = record.routeName ?? ""; runtimeCleanTime = record.runtimeCleanTime.map(String.init) ?? ""
            envText = AdminJSONCodec.pretty(record.env ?? .object([:]))
            if let b64 = record.jsScriptBase64, let data = Data(base64Encoded: b64), let decoded = String(data: data, encoding: .utf8) { script = decoded }
        } catch { message = "读取 Worker 失败：\(error.localizedDescription)" }
    }
    @MainActor private func save() async {
        guard let token = KeychainStore.shared.token(for: server.id) else { message = "未找到 Token"; return }
        do {
            isSaving = true; defer { isSaving = false }
            let env = try AdminJSONCodec.parse(envText)
            let b64 = Data(script.utf8).base64EncodedString()
            let client = NodeGetClient(baseURL: server.baseURL)
            if workerName == nil { _ = try await client.createJSWorker(token: token, name: name, description: description, jsScriptBase64: b64, routeName: routeName, runtimeCleanTime: Int(runtimeCleanTime), env: env) }
            else { _ = try await client.updateJSWorker(token: token, name: name, description: description, jsScriptBase64: b64, routeName: routeName, runtimeCleanTime: Int(runtimeCleanTime), env: env) }
            onDone(); dismiss()
        } catch { message = "保存失败：\(error.localizedDescription)" }
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
                        Text(title).font(.system(size: 30, weight: .black, design: .rounded)).foregroundStyle(Color.ngText)
                        Text(message).font(.subheadline.weight(.semibold)).foregroundStyle(Color.ngMuted).fixedSize(horizontal: false, vertical: true)
                    }
                    if loading { ProgressView().frame(maxWidth: .infinity).padding(24).ngSoftCard() }
                    content()
                }.padding(20).padding(.bottom, 32)
            }
        }.navigationBarTitleDisplayMode(.inline)
    }
}

struct AdminFormPage<Content: View>: View {
    let title: String
    let message: String
    let saving: Bool
    @ViewBuilder let content: () -> Content
    var body: some View {
        ZStack { AppBackgroundView(); ScrollView { VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.system(size: 30, weight: .black, design: .rounded)).foregroundStyle(Color.ngText)
            Text(message).font(.subheadline.weight(.semibold)).foregroundStyle(Color.ngMuted).fixedSize(horizontal: false, vertical: true)
            if saving { ProgressView().frame(maxWidth: .infinity).padding(18).ngSoftCard() }
            content()
        }.padding(20).padding(.bottom, 32) } }
    }
}

struct AdminEmptyCard: View { let text: String; var body: some View { Text(text).font(.subheadline.weight(.semibold)).foregroundStyle(Color.ngMuted).frame(maxWidth: .infinity, alignment: .leading).padding(18).ngSoftCard() } }
struct AdminSmallBadge: View { let text: String; init(_ text: String) { self.text = text }; var body: some View { Text(text).font(.caption.weight(.black)).foregroundStyle(Color.ngPrimary).padding(.horizontal, 9).padding(.vertical, 5).background(Capsule().fill(Color.ngPrimarySoft)) } }
struct AdminActionCapsule: View { let title: String; let icon: String; var body: some View { Label(title, systemImage: icon).font(.caption.weight(.black)).foregroundStyle(Color.ngPrimary).padding(.horizontal, 10).padding(.vertical, 8).background(Capsule().fill(Color.ngPrimarySoft)) } }
struct AdminDangerCapsule: View { let title: String; let icon: String; var body: some View { Label(title, systemImage: icon).font(.caption.weight(.black)).foregroundStyle(.red).padding(.horizontal, 10).padding(.vertical, 8).background(Capsule().fill(Color.red.opacity(0.12))) } }
struct AdminPrimaryButtonLabel: View { let title: String; let icon: String; var body: some View { Label(title, systemImage: icon).font(.headline.weight(.black)).frame(maxWidth: .infinity).padding(.vertical, 14).foregroundStyle(.white).background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.ngPrimary)) } }

struct AdminTextField: View {
    let title: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline).foregroundStyle(Color.ngMuted)
            TextField(title, text: $text).textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(keyboard).padding(14).background(RoundedRectangle(cornerRadius: 16).fill(Color.white)).overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.ngBorder, lineWidth: 1))
        }.padding(14).ngSoftCard()
    }
}

struct AdminJSONEditor: View {
    let title: String
    @Binding var text: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline).foregroundStyle(Color.ngMuted)
            TextEditor(text: $text).font(.caption.monospaced()).frame(minHeight: 180).padding(8).background(RoundedRectangle(cornerRadius: 16).fill(Color.white)).overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.ngBorder, lineWidth: 1))
        }.padding(14).ngSoftCard()
    }
}

enum AdminJSONCodec {
    static func parse(_ text: String) throws -> JSONValue {
        let data = Data(text.utf8)
        let object = try JSONSerialization.jsonObject(with: data, options: [])
        return convert(object)
    }
    static func convert(_ object: Any) -> JSONValue {
        if object is NSNull { return .null }
        if let value = object as? Bool { return .bool(value) }
        if let value = object as? NSNumber { return .number(value.doubleValue) }
        if let value = object as? String { return .string(value) }
        if let array = object as? [Any] { return .array(array.map(convert)) }
        if let dict = object as? [String: Any] { return .object(dict.mapValues(convert)) }
        return .null
    }
    static func pretty(_ value: JSONValue) -> String {
        guard let data = try? JSONEncoder().encode(value), let object = try? JSONSerialization.jsonObject(with: data), let pretty = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]), let string = String(data: pretty, encoding: .utf8) else { return "null" }
        return string
    }
}

extension KVValueRow: Identifiable {
    public var id: String { namespace + "|" + key }
}
