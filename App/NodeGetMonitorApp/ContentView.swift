import SwiftUI

private enum HomeMenuSheet: String, Identifiable {
    case settings
    case billing
    case about
    case privacy

    var id: String { rawValue }
}

struct ContentView: View {
    @EnvironmentObject private var serverStore: ServerProfileStore
    @State private var activeSheet: HomeMenuSheet?

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView()

                if serverStore.servers.isEmpty {
                    EmptyHomeView(openSettings: { activeSheet = .settings })
                } else {
                    MultiServerHomeDashboardView()
                        .environmentObject(serverStore)
                }
            }
            .navigationTitle("NodeGet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button { activeSheet = .settings } label: {
                            Label("设置", systemImage: "gearshape")
                        }
                        Button { activeSheet = .billing } label: {
                            Label("到期 / 续费", systemImage: "calendar.badge.clock")
                        }
                        Button { activeSheet = .about } label: {
                            Label("关于", systemImage: "info.circle")
                        }
                        Button { activeSheet = .privacy } label: {
                            Label("隐私", systemImage: "hand.raised")
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal")
                            .font(.title3.weight(.bold))
                    }
                }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .settings:
                    SettingsView().environmentObject(serverStore)
                case .billing:
                    BillingOverviewView().environmentObject(serverStore)
                case .about:
                    AboutView()
                case .privacy:
                    PrivacyView()
                }
            }
        }
    }
}

struct MultiServerHomeDashboardView: View {
    @EnvironmentObject private var serverStore: ServerProfileStore

    @State private var agentUUIDsByServer: [UUID: [String]] = [:]
    @State private var summariesByServer: [UUID: [AgentSummary]] = [:]
    @State private var staticInfoByServerAndUUID: [String: StaticAgentInfo] = [:]
    @State private var metaByServerAndUUID: [String: AgentMeta] = [:]
    @State private var messagesByServer: [UUID: String] = [:]
    @State private var lastRefresh: Date?
    @State private var isLoading = false
    @State private var isRefreshing = false
    @State private var searchText = ""

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                header

                if totalAgentCount == 0 && !isLoading {
                    emptyView
                } else {
                    ForEach(serverStore.servers) { server in
                        let summaries = filteredSummaries(for: server)
                        if !summaries.isEmpty {
                            serverSection(server: server, summaries: summaries)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 32)
        }
        .searchable(text: $searchText, prompt: "搜索节点 / 主控…")
        .task(id: serverStore.servers.map(\.id).description) {
            await refreshAll()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { break }
                await refreshAll(showLoading: false)
            }
        }
        .refreshable { await refreshAll() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                DashboardPill(title: "Agent", value: "\(totalAgentCount)")
                DashboardPill(title: "主控", value: "\(serverStore.servers.count)", active: false)
                Spacer()
                Button { Task { await refreshAll() } } label: {
                    if isLoading {
                        ProgressView().tint(Color.ngPrimary).frame(width: 42, height: 42)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Color.ngPrimary)
                            .frame(width: 42, height: 42)
                    }
                }
                .background(Circle().fill(Color.ngPrimarySoft))
            }

            Text(statusMessage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.ngMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(isLoading ? "正在读取 Agent…" : "暂无 Agent 数据")
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(Color.ngText)
            Text("首页会聚合显示全部主控下的 Agent。下拉或等待 1 秒会自动刷新。")
                .font(.subheadline)
                .foregroundStyle(Color.ngMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .ngSoftCard()
    }

    private func serverSection(server: ServerProfile, summaries: [AgentSummary]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(server.name)
                        .font(.headline.weight(.black))
                        .foregroundStyle(Color.ngText)
                    Text(server.baseURL.host ?? server.baseURL.absoluteString)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.ngMuted)
                }
                Spacer()
                Text("\(summaries.count)")
                    .font(.caption.weight(.black))
                    .foregroundStyle(Color.ngPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.ngPrimarySoft))
            }

            ForEach(summaries) { summary in
                NavigationLink {
                    AgentDetailView(
                        server: server,
                        uuid: summary.uuid,
                        summary: summary,
                        staticInfo: staticInfo(server: server, uuid: summary.uuid),
                        meta: meta(server: server, uuid: summary.uuid)
                    )
                } label: {
                    DashboardAgentCardView(
                        summary: summary,
                        staticInfo: staticInfo(server: server, uuid: summary.uuid),
                        meta: meta(server: server, uuid: summary.uuid)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var totalAgentCount: Int {
        summariesByServer.values.reduce(0) { $0 + $1.count }
    }

    private var statusMessage: String {
        let time = lastRefresh.map { NodeGetFormatters.clockTime($0) } ?? "--"
        let failures = messagesByServer.values.filter { $0.contains("失败") }
        if failures.isEmpty {
            return "已连接 \(serverStore.servers.count) 个主控，读取到 \(totalAgentCount) 个 Agent。每 1 秒自动刷新于 \(time)。"
        }
        return "读取到 \(totalAgentCount) 个 Agent；部分主控失败：\(failures.prefix(2).joined(separator: "；"))"
    }

    private func cacheKey(server: ServerProfile, uuid: String) -> String {
        "\(server.id.uuidString)|\(uuid)"
    }

    private func staticInfo(server: ServerProfile, uuid: String) -> StaticAgentInfo? {
        staticInfoByServerAndUUID[cacheKey(server: server, uuid: uuid)]
    }

    private func meta(server: ServerProfile, uuid: String) -> AgentMeta? {
        metaByServerAndUUID[cacheKey(server: server, uuid: uuid)]
    }

    private func displayName(server: ServerProfile, uuid: String) -> String {
        meta(server: server, uuid: uuid)?.name.nilIfEmpty ?? staticInfo(server: server, uuid: uuid)?.displayName ?? uuid
    }

    private func filteredSummaries(for server: ServerProfile) -> [AgentSummary] {
        let sorted = summariesByServer[server.id, default: []].sorted { left, right in
            displayName(server: server, uuid: left.uuid).localizedCaseInsensitiveCompare(displayName(server: server, uuid: right.uuid)) == .orderedAscending
        }
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return sorted }
        return sorted.filter { summary in
            let info = staticInfo(server: server, uuid: summary.uuid)
            let meta = meta(server: server, uuid: summary.uuid)
            let candidates = [summary.uuid, server.name, server.baseURL.absoluteString, displayName(server: server, uuid: summary.uuid), meta?.region ?? "", info?.systemLine ?? "", info?.cpuLine ?? ""]
            return candidates.joined(separator: " ").localizedCaseInsensitiveContains(keyword)
        }
    }

    private func refreshAll(showLoading: Bool = true) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        if showLoading { isLoading = true }
        defer {
            isRefreshing = false
            if showLoading { isLoading = false }
        }

        for server in serverStore.servers {
            await refresh(server: server)
        }
        lastRefresh = Date()
    }

    private func refresh(server: ServerProfile) async {
        guard let token = KeychainStore.shared.token(for: server.id) else {
            messagesByServer[server.id] = "\(server.name) 失败：未找到 Token"
            return
        }
        let client = NodeGetClient(baseURL: server.baseURL)
        do {
            let uuids = try await client.listAllAgentUUIDs(token: token).sorted()
            agentUUIDsByServer[server.id] = uuids
            let latest = try await client.latestDynamicSummaries(token: token, uuids: uuids)
            LocalTrendStore.shared.append(contentsOf: latest)
            summariesByServer[server.id] = latest

            if staticInfoByServerAndUUID.keys.filter({ $0.hasPrefix(server.id.uuidString) }).isEmpty {
                if let map = try? await client.latestStaticInfoMap(token: token, uuids: uuids) {
                    for (uuid, info) in map { staticInfoByServerAndUUID[cacheKey(server: server, uuid: uuid)] = info }
                }
            }

            if let metas = try? await client.metadataMap(token: token, uuids: uuids) {
                for (uuid, meta) in metas { metaByServerAndUUID[cacheKey(server: server, uuid: uuid)] = meta }
            }
            messagesByServer[server.id] = "\(server.name) OK"
        } catch {
            messagesByServer[server.id] = "\(server.name) 失败：\(error.localizedDescription)"
        }
    }
}

struct EmptyHomeView: View {
    let openSettings: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("还没有配置主控")
                        .font(.title2.bold())
                    Text("点右上角菜单进入设置，添加 NodeGet Server 地址和 Token。配置完成后，首页会直接显示 Agent 列表。")
                        .font(.subheadline)
                        .foregroundStyle(Color.ngMuted)
                        .fixedSize(horizontal: false, vertical: true)

                    Button { openSettings() } label: {
                        Label("打开设置", systemImage: "gearshape.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: 18).fill(Color.ngPrimary))
                            .foregroundStyle(.white)
                    }
                    .padding(.top, 8)
                }
                .padding(20)
                .ngSoftCard()
            }
            .padding(20)
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var serverStore: ServerProfileStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView()
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Text("设置")
                            .font(.system(size: 34, weight: .black, design: .rounded))

                        NavigationLink {
                            AddServerView().environmentObject(serverStore)
                        } label: {
                            HomeActionCard(icon: "plus.circle.fill", title: "添加主控", subtitle: "配置 NodeGet Server 地址与 Token")
                        }
                        .buttonStyle(.plain)

                        VStack(alignment: .leading, spacing: 12) {
                            SectionCaption(text: "主控地址")
                            if serverStore.servers.isEmpty {
                                Text("暂无主控。")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.ngMuted)
                                    .padding(18)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .ngSoftCard()
                            } else {
                                ForEach(serverStore.servers) { server in
                                    HStack(spacing: 12) {
                                        VStack(alignment: .leading, spacing: 6) {
                                            Text(server.name).font(.headline).foregroundStyle(Color.ngText)
                                            Text(server.baseURL.absoluteString).font(.caption).foregroundStyle(Color.ngMuted).lineLimit(1)
                                        }
                                        Spacer()
                                        Button(role: .destructive) { serverStore.delete(server) } label: { Image(systemName: "trash") }
                                    }
                                    .padding(18)
                                    .ngSoftCard()
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() } } }
        }
    }
}

struct BillingOverviewView: View {
    @EnvironmentObject private var serverStore: ServerProfileStore
    @Environment(\.dismiss) private var dismiss
    @State private var items: [BillingOverviewItem] = []
    @State private var message = "正在读取到期与续费信息…"
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView()
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        Text("到期 / 续费")
                            .font(.system(size: 34, weight: .black, design: .rounded))
                        Text(message)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.ngMuted)
                            .fixedSize(horizontal: false, vertical: true)

                        if isLoading { ProgressView().frame(maxWidth: .infinity) }

                        ForEach(groupedServers, id: \.id) { server in
                            VStack(alignment: .leading, spacing: 12) {
                                SectionCaption(text: server.name)
                                let rows = items.filter { $0.server.id == server.id }
                                if rows.isEmpty {
                                    Text("暂无费用数据。")
                                        .font(.subheadline)
                                        .foregroundStyle(Color.ngMuted)
                                        .padding(18)
                                        .ngSoftCard()
                                } else {
                                    ForEach(rows) { item in BillingItemCard(item: item) }
                                }
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("到期 / 续费")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("刷新") { Task { await load() } } }
                ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() } }
            }
            .task { await load() }
        }
    }

    private var groupedServers: [ServerProfile] { serverStore.servers }

    private func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        var output: [BillingOverviewItem] = []
        var errors: [String] = []

        for server in serverStore.servers {
            guard let token = KeychainStore.shared.token(for: server.id) else {
                errors.append("\(server.name)：缺少 Token")
                continue
            }
            let client = NodeGetClient(baseURL: server.baseURL)
            do {
                let uuids = try await client.listAllAgentUUIDs(token: token).sorted()
                let meta = try await client.metadataMap(token: token, uuids: uuids)
                let staticMap = (try? await client.latestStaticInfoMap(token: token, uuids: uuids)) ?? [:]
                for uuid in uuids {
                    output.append(BillingOverviewItem(server: server, uuid: uuid, meta: meta[uuid], staticInfo: staticMap[uuid]))
                }
            } catch {
                errors.append("\(server.name)：\(error.localizedDescription)")
            }
        }

        items = output.sorted { left, right in
            let l = left.meta?.remainingDays ?? Int.max
            let r = right.meta?.remainingDays ?? Int.max
            if l != r { return l < r }
            return left.displayName.localizedCaseInsensitiveCompare(right.displayName) == .orderedAscending
        }
        message = errors.isEmpty ? "读取到 \(items.count) 台机器的费用信息。" : "读取到 \(items.count) 台机器；部分失败：\(errors.prefix(2).joined(separator: "；"))"
    }
}

struct BillingOverviewItem: Identifiable {
    let server: ServerProfile
    let uuid: String
    let meta: AgentMeta?
    let staticInfo: StaticAgentInfo?

    var id: String { "\(server.id.uuidString)-\(uuid)" }
    var displayName: String { meta?.name.nilIfEmpty ?? staticInfo?.displayName ?? uuid }
}

struct BillingItemCard: View {
    let item: BillingOverviewItem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(item.displayName)
                        .font(.title3.weight(.black))
                        .foregroundStyle(Color.ngText)
                    Text(item.uuid)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.ngMuted)
                        .lineLimit(1)
                }
                Spacer()
                remainBadge
            }
            Divider()
            DetailInfoRow(title: "到期", value: NodeGetFormatters.date(item.meta?.expiryDate))
            DetailInfoRow(title: "剩余", value: NodeGetFormatters.days(item.meta?.remainingDays))
            DetailInfoRow(title: "续费金额", value: item.meta?.displayPrice ?? "--")
            DetailInfoRow(title: "计费周期", value: item.meta?.cycleText ?? "--")
        }
        .padding(18)
        .ngSoftCard()
    }

    private var remainBadge: some View {
        let days = item.meta?.remainingDays
        let color: Color = (days ?? 9999) <= 7 ? .red : ((days ?? 9999) <= 30 ? .orange : Color.ngPrimary)
        return Text(days.map { "\($0) 天" } ?? "--")
            .font(.caption.weight(.black))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(color.opacity(0.13)))
    }
}

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView()
                VStack(alignment: .leading, spacing: 16) {
                    Text("NodeGet")
                        .font(.system(size: 38, weight: .black, design: .rounded))
                    Text("iPhone 原生监控仪表盘。")
                        .font(.headline)
                        .foregroundStyle(Color.ngMuted)
                    VStack(spacing: 12) {
                        DetailInfoRow(title: "版本", value: "0.4.9")
                        DetailInfoRow(title: "刷新", value: "首页与详情页每 1 秒自动刷新")
                        DetailInfoRow(title: "构建", value: "Unsigned IPA 文件名会带版本号")
                    }
                    .padding(18)
                    .ngSoftCard()
                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("关于")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() } } }
        }
    }
}

struct PrivacyView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("隐私")
                            .font(.system(size: 38, weight: .black, design: .rounded))
                        Text("Token 保存在本机 iOS Keychain。App 不会把你的主控地址、Token、Agent UUID 或监控数据上传到第三方服务器。")
                            .font(.headline)
                            .foregroundStyle(Color.ngMuted)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(18)
                            .ngSoftCard()
                    }
                    .padding(20)
                }
            }
            .navigationTitle("隐私")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() } } }
        }
    }
}

struct HomeActionCard: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.blue)
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.title3.bold()).foregroundStyle(Color.black)
                Text(subtitle).font(.subheadline).foregroundStyle(Color.ngMuted).fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.headline).foregroundStyle(Color.ngMuted.opacity(0.8))
        }
        .padding(18)
        .ngSoftCard()
    }
}
