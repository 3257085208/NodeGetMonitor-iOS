import SwiftUI
#if canImport(WebKit)
import WebKit
#endif

struct DashboardSuiteView: View {
    @EnvironmentObject private var serverStore: ServerProfileStore
    @State private var selectedServerID: UUID?
    @State private var message = "已融合 NodeGet Dashboard 的主菜单结构。常用功能优先走原生页，复杂页面可用内置 Web Dashboard 桥接打开。"

    private var selectedServer: ServerProfile? {
        if let selectedServerID, let match = serverStore.servers.first(where: { $0.id == selectedServerID }) {
            return match
        }
        return serverStore.servers.first
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView()
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        header
                        if serverStore.servers.isEmpty {
                            emptyCard
                        } else if let server = selectedServer {
                            backendSwitcher
                            quickDashboardBridge(server: server)
                            dashboardSections(server: server)
                        }
                    }
                    .padding(20)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("主控")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if selectedServerID == nil { selectedServerID = serverStore.servers.first?.id }
            }
            .onChange(of: serverStore.servers.map(\.id)) { _, ids in
                if let selectedServerID, ids.contains(selectedServerID) { return }
                self.selectedServerID = ids.first
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("NodeGet Dashboard")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(Color.ngText)
            Text(message)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.ngMuted)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                DashboardPill(title: "主控", value: "\(serverStore.servers.count)")
                DashboardPill(title: "模式", value: "Native + Web", active: false)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("还没有主控")
                .font(.title3.weight(.black))
                .foregroundStyle(Color.ngText)
            Text("先到设置页添加 NodeGet Server 和全权限 Token，主控页会自动显示 Dashboard 功能入口。")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.ngMuted)
        }
        .padding(18)
        .ngSoftCard()
    }

    private var backendSwitcher: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionCaption(text: "当前主控")
            Picker("主控", selection: Binding(
                get: { selectedServerID ?? serverStore.servers.first?.id },
                set: { selectedServerID = $0 }
            )) {
                ForEach(serverStore.servers) { server in
                    Text(server.name).tag(Optional(server.id))
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Color.ngBorder, lineWidth: 1))
        }
    }

    private func quickDashboardBridge(server: ServerProfile) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionCaption(text: "完整 Dashboard")
            NavigationLink {
                DashboardWebBridgeView(server: server, route: "/dashboard/overview", title: "完整 Dashboard")
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "rectangle.on.rectangle.angled")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Color.ngPrimary)
                        .frame(width: 42, height: 42)
                        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.ngPrimarySoft))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("打开 Web Dashboard 兼容层")
                            .font(.headline.weight(.black))
                            .foregroundStyle(Color.ngText)
                        Text("自动注入当前主控 URL 和 Token。适合 WebShell、文件管理、扩展详情等复杂页面。")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.ngMuted)
                            .fixedSize(horizontal: false, vertical: true)
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

    private func dashboardSections(server: ServerProfile) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            DashboardSectionView(title: "监控", modules: [
                DashboardModule(title: "服务概览", subtitle: "列表模式、资源条、网络速率", icon: "server.rack", destination: AnyView(AdminServerOverviewListView(server: server))),
                DashboardModule(title: "节点管理", subtitle: "被控节点、metadata、节点设置", icon: "cpu", destination: AnyView(AdminAgentManageView(server: server))),
                DashboardModule(title: "全球地图", subtitle: "区域分布、节点列表、Web 地图桥接", icon: "globe.asia.australia", destination: AnyView(AdminGlobalMapView(server: server))),
            ])

            DashboardSectionView(title: "工具", modules: [
                DashboardModule(title: "定时任务", subtitle: "Cron 创建、编辑、启停、删除", icon: "calendar.badge.clock", destination: AnyView(AdminCronListView(server: server))),
                DashboardModule(title: "成本管理", subtitle: "资产、到期、续费、币种折算", icon: "creditcard", destination: AnyView(BillingOverviewView())),
                DashboardModule(title: "脚本片段", subtitle: "script_snippet KV 增删改查", icon: "doc.text", destination: AnyView(AdminKVEntryView(server: server, namespace: "script_snippet"))),
                DashboardModule(title: "批量执行", subtitle: "选择节点并执行 shell 命令", icon: "terminal", destination: AnyView(AdminBatchExecuteView(server: server))),
            ])

            DashboardSectionView(title: "高级", modules: [
                DashboardModule(title: "Token", subtitle: "创建、导入、权限 JSON、删除", icon: "key.horizontal", destination: AnyView(AdminTokenListView(server: server))),
                DashboardModule(title: "KV 管理", subtitle: "Namespace / Key / Value", icon: "externaldrive", destination: AnyView(AdminKVNamespaceView(server: server))),
                DashboardModule(title: "JS Worker", subtitle: "创建、编辑、运行、删除", icon: "curlybraces.square", destination: AnyView(AdminWorkersView(server: server))),
            ])

            DashboardSectionView(title: "应用扩展", modules: [
                DashboardModule(title: "扩展管理", subtitle: "安装、列表、详情、文件", icon: "shippingbox", destination: AnyView(DashboardWebBridgeView(server: server, route: "/dashboard/app-panel/list", title: "扩展管理"))),
            ])

            DashboardSectionView(title: "节点详情工具", modules: [
                DashboardModule(title: "运行状态", subtitle: "CPU / Memory / Disk / Network", icon: "waveform.path.ecg", destination: AnyView(AdminNodeToolPickerView(server: server, mode: .status))),
                DashboardModule(title: "延迟曲线", subtitle: "Ping / TCP Ping 历史", icon: "antenna.radiowaves.left.and.right", destination: AnyView(AdminNodeToolPickerView(server: server, mode: .latency))),
                DashboardModule(title: "流量统计", subtitle: "入站 / 出站 / 合计", icon: "arrow.up.arrow.down", destination: AnyView(AdminNodeToolPickerView(server: server, mode: .traffic))),
                DashboardModule(title: "Ping 检测", subtitle: "地图、直方图、表格", icon: "target", destination: AnyView(DashboardWebBridgeView(server: server, route: "/dashboard/node-manage", title: "Ping 检测"))),
                DashboardModule(title: "WebShell 终端", subtitle: "通过 Dashboard WebSocket 终端", icon: "terminal.fill", destination: AnyView(AdminNodeToolPickerView(server: server, mode: .webshell))),
                DashboardModule(title: "文件管理", subtitle: "节点文件操作", icon: "folder", destination: AnyView(AdminNodeToolPickerView(server: server, mode: .files))),
                DashboardModule(title: "节点设置", subtitle: "基本 / 配置 / 上游 / 存储 / 删除", icon: "gearshape", destination: AnyView(AdminNodeToolPickerView(server: server, mode: .setting))),
            ])

            DashboardSectionView(title: "系统", modules: [
                DashboardModule(title: "设置", subtitle: "App 设置与主控配置", icon: "gear", destination: AnyView(SettingsView())),
                DashboardModule(title: "日志", subtitle: "Dashboard 日志面板", icon: "doc.plaintext", destination: AnyView(DashboardWebBridgeView(server: server, route: "/dashboard/logs", title: "日志"))),
                DashboardModule(title: "关于", subtitle: "NodeGet Monitor / GitHub", icon: "info.circle", destination: AnyView(DashboardAboutNativeView())),
            ])
        }
    }
}

struct DashboardModule: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let destination: AnyView
}

struct DashboardSectionView: View {
    let title: String
    let modules: [DashboardModule]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionCaption(text: title)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(modules) { module in
                    NavigationLink { module.destination } label: {
                        DashboardModuleCard(module: module)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct DashboardModuleCard: View {
    let module: DashboardModule

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: module.icon)
                .font(.title2.weight(.bold))
                .foregroundStyle(Color.ngPrimary)
                .frame(width: 42, height: 42)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.ngPrimarySoft))
            Text(module.title)
                .font(.headline.weight(.black))
                .foregroundStyle(Color.ngText)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Text(module.subtitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.ngMuted)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .ngSoftCard()
    }
}

struct DashboardWebBridgeView: View {
    let server: ServerProfile
    let route: String
    let title: String

    @State private var token = ""

    var body: some View {
        VStack(spacing: 0) {
            #if canImport(WebKit)
            DashboardWebView(url: webURL, server: server, token: token)
            #else
            Text("当前环境不支持 WebKit。")
                .padding()
            #endif
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .task { token = KeychainStore.shared.token(for: server.id) ?? "" }
    }

    private var webURL: URL {
        var base = server.baseURL.absoluteString
        if base.hasSuffix("/") { base.removeLast() }
        let normalizedRoute = route.hasPrefix("/") ? route : "/" + route
        return URL(string: base + "/#" + normalizedRoute) ?? server.baseURL
    }
}

#if canImport(WebKit)
struct DashboardWebView: UIViewRepresentable {
    let url: URL
    let server: ServerProfile
    let token: String

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let controller = WKUserContentController()
        controller.addUserScript(WKUserScript(source: localStorageScript(), injectionTime: .atDocumentStart, forMainFrameOnly: false))
        configuration.userContentController = controller
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if webView.url != url {
            webView.load(URLRequest(url: url))
        }
    }

    private func localStorageScript() -> String {
        let wsURL = server.baseURL.dashboardWebSocketURLString
        let backend: [String: String] = ["name": server.name, "url": wsURL, "token": token]
        let data = (try? JSONSerialization.data(withJSONObject: backend, options: [])) ?? Data()
        let json = String(data: data, encoding: .utf8) ?? "{}"
        let escaped = json.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "'", with: "\\'")
        return """
        try {
          const backend = JSON.parse('\(escaped)');
          localStorage.setItem('nodeget_backends', JSON.stringify([backend]));
          localStorage.setItem('nodeget_current_backend', JSON.stringify(backend));
        } catch (e) { console.log(e); }
        """
    }
}
#endif

private extension URL {
    var dashboardWebSocketURLString: String {
        var components = URLComponents(url: self, resolvingAgainstBaseURL: false)
        if components?.scheme == "https" { components?.scheme = "wss" }
        else if components?.scheme == "http" { components?.scheme = "ws" }
        return components?.url?.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/")) ?? absoluteString
    }
}

struct AdminServerOverviewListView: View {
    let server: ServerProfile
    @State private var rows: [AdminServerOverviewRow] = []
    @State private var message = "正在读取服务概览…"
    @State private var isLoading = false

    var body: some View {
        AdminListPage(title: "服务概览", message: message, loading: isLoading) {
            if rows.isEmpty && !isLoading { AdminEmptyCard(text: "暂无节点数据。") }
            ForEach(rows) { row in
                AdminServerOverviewCard(row: row)
            }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    @MainActor private func load() async {
        guard let token = KeychainStore.shared.token(for: server.id) else { message = "未找到 Token"; return }
        isLoading = true; defer { isLoading = false }
        do {
            let client = NodeGetClient(baseURL: server.baseURL)
            let uuids = try await client.listAllAgentUUIDs(token: token).sorted()
            let summaries = try await client.latestDynamicSummaries(token: token, uuids: uuids)
            let staticMap = (try? await client.latestStaticInfoMap(token: token, uuids: uuids)) ?? [:]
            let metaMap = (try? await client.metadataMap(token: token, uuids: uuids)) ?? [:]
            rows = summaries.map { summary in
                let info = staticMap[summary.uuid]
                let meta = metaMap[summary.uuid]
                return AdminServerOverviewRow(
                    uuid: summary.uuid,
                    name: meta?.name.nilIfEmpty ?? info?.displayName ?? summary.uuid,
                    region: meta?.region,
                    os: info?.systemLine.nilIfEmpty ?? "--",
                    cpu: summary.cpuUsage ?? 0,
                    memory: summary.memoryUsagePercent ?? 0,
                    disk: summary.diskUsagePercent ?? 0,
                    uptime: summary.uptime,
                    rx: summary.receiveSpeed,
                    tx: summary.transmitSpeed
                )
            }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            message = "读取到 \(rows.count) 个节点。"
        } catch { message = "读取失败：\(error.localizedDescription)" }
    }
}


struct AdminServerOverviewCard: View {
    let row: AdminServerOverviewRow

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            MetricProgressLine(title: "CPU", value: row.cpu, tint: .cyan)
            MetricProgressLine(title: "RAM", value: row.memory, tint: Color.ngPrimary)
            MetricProgressLine(title: "Disk", value: row.disk, tint: .orange)
            footer
        }
        .padding(16)
        .ngSoftCard()
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(row.name)
                    .font(.headline.weight(.black))
                    .foregroundStyle(Color.ngText)
                Text(row.subtitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.ngMuted)
            }
            Spacer()
            AdminSmallBadge(row.region?.nilIfEmpty ?? "--")
        }
    }

    private var footer: some View {
        HStack {
            Label(NodeGetFormatters.uptime(row.uptime), systemImage: "clock")
            Spacer()
            Text("↓ \(NodeGetFormatters.speed(row.rx))  ↑ \(NodeGetFormatters.speed(row.tx))")
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(Color.ngMuted)
    }
}

struct AdminServerOverviewRow: Identifiable {
    var id: String { uuid }
    let uuid: String
    let name: String
    let region: String?
    let os: String
    let cpu: Double
    let memory: Double
    let disk: Double
    let uptime: Int64?
    let rx: Double?
    let tx: Double?

    var subtitle: String {
        String(uuid.prefix(8)) + " · " + os
    }
}

struct MetricProgressLine: View {
    let title: String
    let value: Double
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(title)
                Spacer()
                Text(NodeGetFormatters.percent(value))
            }
            .font(.caption.weight(.bold))
            .foregroundStyle(Color.ngMuted)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(tint.opacity(0.16))
                    Capsule().fill(tint).frame(width: geo.size.width * CGFloat(min(max(value / 100, 0), 1)))
                }
            }
            .frame(height: 6)
        }
    }
}

struct AdminGlobalMapView: View {
    let server: ServerProfile
    @State private var regions: [(String, Int)] = []
    @State private var message = "正在读取地区分布…"
    @State private var isLoading = false

    var body: some View {
        AdminListPage(title: "全球地图", message: message, loading: isLoading) {
            VStack(alignment: .leading, spacing: 12) {
                NavigationLink { DashboardWebBridgeView(server: server, route: "/dashboard/map", title: "全球地图") } label: {
                    AdminActionCapsule(title: "打开 Web 2D/3D 地图", icon: "globe")
                }
                .buttonStyle(.plain)
                ForEach(regions, id: \.0) { region, count in
                    HStack {
                        Text(region).font(.headline.weight(.black)).foregroundStyle(Color.ngText)
                        Spacer()
                        AdminSmallBadge("\(count) 台")
                    }
                    .padding(16)
                    .ngSoftCard()
                }
            }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    @MainActor private func load() async {
        guard let token = KeychainStore.shared.token(for: server.id) else { message = "未找到 Token"; return }
        isLoading = true; defer { isLoading = false }
        do {
            let client = NodeGetClient(baseURL: server.baseURL)
            let uuids = try await client.listAllAgentUUIDs(token: token)
            let metaMap = (try? await client.metadataMap(token: token, uuids: uuids)) ?? [:]
            let grouped = Dictionary(grouping: metaMap.values) { $0.region?.nilIfEmpty ?? "未设置" }
            regions = grouped.map { ($0.key, $0.value.count) }.sorted { $0.0 < $1.0 }
            message = "读取到 \(regions.reduce(0) { $0 + $1.1 }) 台节点，\(regions.count) 个地区。"
        } catch { message = "读取失败：\(error.localizedDescription)" }
    }
}

enum AdminNodeToolMode: String, CaseIterable, Identifiable {
    case status = "运行状态"
    case latency = "延迟曲线"
    case traffic = "流量统计"
    case webshell = "WebShell"
    case files = "文件管理"
    case setting = "节点设置"
    var id: String { rawValue }
    var routeSuffix: String {
        switch self {
        case .status: return "status"
        case .latency: return "latency"
        case .traffic: return "traffic"
        case .webshell: return "webshell"
        case .files: return "files"
        case .setting: return "setting"
        }
    }
}

struct AdminNodeToolPickerView: View {
    let server: ServerProfile
    let mode: AdminNodeToolMode
    @State private var rows: [AdminAgentRow] = []
    @State private var message = "选择一个节点打开 \"\(AdminNodeToolMode.status.rawValue)\"。"
    @State private var isLoading = false

    var body: some View {
        AdminListPage(title: mode.rawValue, message: message, loading: isLoading) {
            if rows.isEmpty && !isLoading { AdminEmptyCard(text: "暂无节点。") }
            ForEach(rows) { row in
                NavigationLink {
                    if mode == .status {
                        AgentDetailView(server: server, uuid: row.uuid, summary: nil, staticInfo: nil, meta: nil)
                    } else {
                        DashboardWebBridgeView(server: server, route: "/dashboard/node/\(row.uuid)/\(mode.routeSuffix)", title: "\(row.displayName) · \(mode.rawValue)")
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(row.displayName).font(.headline.weight(.black)).foregroundStyle(Color.ngText)
                            Text(row.uuid).font(.caption.monospaced()).foregroundStyle(Color.ngMuted).lineLimit(1)
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
        isLoading = true; defer { isLoading = false }
        do {
            let client = NodeGetClient(baseURL: server.baseURL)
            let uuids = try await client.listAllAgentUUIDs(token: token).sorted()
            let staticMap = (try? await client.latestStaticInfoMap(token: token, uuids: uuids)) ?? [:]
            let metaMap = (try? await client.metadataMap(token: token, uuids: uuids)) ?? [:]
            rows = uuids.map { uuid in AdminAgentRow(uuid: uuid, meta: metaMap[uuid], staticInfo: staticMap[uuid]) }
            message = "选择一个节点打开 \(mode.rawValue)。"
        } catch { message = "读取失败：\(error.localizedDescription)" }
    }
}

struct AdminBatchExecuteView: View {
    let server: ServerProfile
    @State private var rows: [AdminAgentRow] = []
    @State private var selected: Set<String> = []
    @State private var shell = "bash"
    @State private var code = "uname -a"
    @State private var message = "批量执行会在目标 Agent 上运行命令，请确认目标和命令。"
    @State private var isLoading = false

    var body: some View {
        AdminListPage(title: "批量执行", message: message, loading: isLoading) {
            VStack(alignment: .leading, spacing: 12) {
                AdminTextField(title: "解释器（bash / sh / cmd）", text: $shell)
                AdminJSONEditor(title: "命令", text: $code)
                HStack {
                    Button("全选") { selected = Set(rows.map(\.uuid)) }.buttonStyle(.bordered)
                    Button("清空") { selected.removeAll() }.buttonStyle(.bordered)
                    Spacer()
                    NavigationLink { DashboardWebBridgeView(server: server, route: "/dashboard/batch-exec", title: "批量执行 Web") } label: { AdminActionCapsule(title: "Web 高级执行", icon: "rectangle.on.rectangle") }.buttonStyle(.plain)
                }
                ForEach(rows) { row in
                    Button { toggle(row.uuid) } label: {
                        HStack {
                            Image(systemName: selected.contains(row.uuid) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selected.contains(row.uuid) ? Color.ngPrimary : Color.ngMuted)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(row.displayName).font(.headline.weight(.black)).foregroundStyle(Color.ngText)
                                Text(row.uuid).font(.caption.monospaced()).foregroundStyle(Color.ngMuted).lineLimit(1)
                            }
                            Spacer()
                        }
                        .padding(14)
                        .ngSoftCard()
                    }.buttonStyle(.plain)
                }
                Button { message = "已选择 \(selected.count) 个节点。原生命令下发将在 v0.7.x 接入 task_create_task_blocking；当前可点 Web 高级执行使用完整 Dashboard 批量执行。" } label: {
                    AdminPrimaryButtonLabel(title: "确认执行", icon: "play.circle")
                }
            }
        }
        .task { await load() }
        .refreshable { await load() }
    }

    private func toggle(_ uuid: String) {
        if selected.contains(uuid) { selected.remove(uuid) } else { selected.insert(uuid) }
    }

    @MainActor private func load() async {
        guard let token = KeychainStore.shared.token(for: server.id) else { message = "未找到 Token"; return }
        isLoading = true; defer { isLoading = false }
        do {
            let client = NodeGetClient(baseURL: server.baseURL)
            let uuids = try await client.listAllAgentUUIDs(token: token).sorted()
            let staticMap = (try? await client.latestStaticInfoMap(token: token, uuids: uuids)) ?? [:]
            let metaMap = (try? await client.metadataMap(token: token, uuids: uuids)) ?? [:]
            rows = uuids.map { uuid in AdminAgentRow(uuid: uuid, meta: metaMap[uuid], staticInfo: staticMap[uuid]) }
            message = "读取到 \(rows.count) 个节点。"
        } catch { message = "读取失败：\(error.localizedDescription)" }
    }
}

struct DashboardAboutNativeView: View {
    var body: some View {
        AdminListPage(title: "关于", message: "NodeGet Monitor · v0.8.1", loading: false) {
            VStack(alignment: .leading, spacing: 12) {
                Text("NodeGet Monitor")
                    .font(.title2.weight(.black))
                    .foregroundStyle(Color.ngText)
                Text("iOS 原生监控 + 主控端，融合 NodeGet StatusShow 与 NodeGet Dashboard 的主要功能入口。")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.ngMuted)
                    .fixedSize(horizontal: false, vertical: true)
                Link("GitHub 开源地址", destination: URL(string: "https://github.com/3257085208/NodeGetMonitor-iOS")!)
                    .font(.headline.weight(.black))
            }
            .padding(18)
            .ngSoftCard()
        }
    }
}
