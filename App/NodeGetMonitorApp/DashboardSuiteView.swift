import SwiftUI
#if canImport(WebKit)
import WebKit
#endif

struct DashboardSuiteView: View {
    @EnvironmentObject private var serverStore: ServerProfileStore
    @State private var selectedServerID: UUID?

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
                    VStack(alignment: .leading, spacing: 18) {
                        header
                        content
                    }
                    .padding(20)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("主控")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if selectedServerID == nil {
                    selectedServerID = serverStore.servers.first?.id
                }
            }
            .onChange(of: serverStore.servers.map(\.id)) { _, ids in
                if let selectedServerID, ids.contains(selectedServerID) { return }
                selectedServerID = ids.first
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("NodeGet Dashboard")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(Color.ngText)
            Text("把 NodeGet Dashboard 的主菜单融合进 App。常用功能走原生页，复杂功能通过内置 Web Dashboard 承接。")
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

    @ViewBuilder
    private var content: some View {
        if serverStore.servers.isEmpty {
            emptyCard
        } else if let server = selectedServer {
            backendSwitcher
            fullDashboardCard(server: server)
            dashboardMenu(server: server)
        }
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

    private func fullDashboardCard(server: ServerProfile) -> some View {
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
                    Text("打开完整 Web Dashboard")
                        .font(.headline.weight(.black))
                        .foregroundStyle(Color.ngText)
                    Text("自动注入当前主控 URL 和 Token，适合 WebShell、文件管理、扩展管理等复杂页面。")
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

    private func dashboardMenu(server: ServerProfile) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            DashboardMenuSection(title: "监控", items: [
                DashboardMenuItem(title: "服务概览", subtitle: "列表模式、资源条、网络速率", icon: "server.rack", kind: .nativeAgentList),
                DashboardMenuItem(title: "节点管理", subtitle: "Agent、metadata、节点设置", icon: "cpu", kind: .nativeAgentManage),
                DashboardMenuItem(title: "全球地图", subtitle: "2D / 3D 地图", icon: "globe.asia.australia", kind: .web("/dashboard/map"))
            ], server: server)

            DashboardMenuSection(title: "工具", items: [
                DashboardMenuItem(title: "定时任务", subtitle: "Cron 创建、编辑、启停、删除", icon: "calendar.badge.clock", kind: .nativeCron),
                DashboardMenuItem(title: "成本管理", subtitle: "资产、到期、续费、币种折算", icon: "creditcard", kind: .nativeBilling),
                DashboardMenuItem(title: "脚本片段", subtitle: "script_snippet KV", icon: "doc.text", kind: .scriptSnippet),
                DashboardMenuItem(title: "批量执行", subtitle: "选择节点并执行命令", icon: "terminal", kind: .nativeBatch)
            ], server: server)

            DashboardMenuSection(title: "高级", items: [
                DashboardMenuItem(title: "Token", subtitle: "创建、导入、权限 JSON、删除", icon: "key.horizontal", kind: .nativeToken),
                DashboardMenuItem(title: "KV 管理", subtitle: "Namespace / Key / Value", icon: "externaldrive", kind: .nativeKV),
                DashboardMenuItem(title: "JS Worker", subtitle: "创建、编辑、运行、删除", icon: "curlybraces.square", kind: .nativeWorker),
                DashboardMenuItem(title: "扩展管理", subtitle: "安装、列表、详情、文件", icon: "shippingbox", kind: .web("/dashboard/app-panel/list"))
            ], server: server)

            DashboardMenuSection(title: "节点详情工具", items: [
                DashboardMenuItem(title: "运行状态", subtitle: "CPU / Memory / Disk / Network", icon: "waveform.path.ecg", kind: .nodePicker("/dashboard/node/%@/status")),
                DashboardMenuItem(title: "延迟曲线", subtitle: "Ping / TCP Ping 历史", icon: "antenna.radiowaves.left.and.right", kind: .nodePicker("/dashboard/node/%@/latency")),
                DashboardMenuItem(title: "流量统计", subtitle: "入站 / 出站 / 合计", icon: "arrow.up.arrow.down", kind: .nodePicker("/dashboard/node/%@/traffic")),
                DashboardMenuItem(title: "Ping 检测", subtitle: "地图、直方图、表格", icon: "target", kind: .web("/dashboard/node-manage")),
                DashboardMenuItem(title: "WebShell 终端", subtitle: "通过 Dashboard WebSocket 终端", icon: "terminal.fill", kind: .nodePicker("/dashboard/node/%@/webshell")),
                DashboardMenuItem(title: "文件管理", subtitle: "节点文件操作", icon: "folder", kind: .nodePicker("/dashboard/node/%@/files")),
                DashboardMenuItem(title: "节点设置", subtitle: "基本 / 配置 / 上游 / 存储 / 删除", icon: "gearshape", kind: .nodePicker("/dashboard/node/%@/setting"))
            ], server: server)

            DashboardMenuSection(title: "系统", items: [
                DashboardMenuItem(title: "设置", subtitle: "App 设置与主控配置", icon: "gear", kind: .nativeSettings),
                DashboardMenuItem(title: "日志", subtitle: "Dashboard 日志面板", icon: "doc.plaintext", kind: .web("/dashboard/logs")),
                DashboardMenuItem(title: "关于", subtitle: "NodeGet Monitor / GitHub", icon: "info.circle", kind: .nativeAbout)
            ], server: server)
        }
    }
}

struct DashboardMenuItem: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let kind: DashboardDestinationKind
}

enum DashboardDestinationKind: Equatable {
    case nativeAgentList
    case nativeAgentManage
    case nativeBilling
    case nativeCron
    case nativeToken
    case nativeKV
    case nativeWorker
    case nativeBatch
    case nativeSettings
    case nativeAbout
    case scriptSnippet
    case web(String)
    case nodePicker(String)
}

struct DashboardMenuSection: View {
    let title: String
    let items: [DashboardMenuItem]
    let server: ServerProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionCaption(text: title)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(items) { item in
                    NavigationLink {
                        DashboardDestinationView(server: server, item: item)
                    } label: {
                        DashboardMenuCard(item: item)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

struct DashboardMenuCard: View {
    let item: DashboardMenuItem

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: item.icon)
                .font(.title2.weight(.bold))
                .foregroundStyle(Color.ngPrimary)
                .frame(width: 42, height: 42)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.ngPrimarySoft))
            Text(item.title)
                .font(.headline.weight(.black))
                .foregroundStyle(Color.ngText)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
            Text(item.subtitle)
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

struct DashboardDestinationView: View {
    let server: ServerProfile
    let item: DashboardMenuItem

    var body: some View {
        switch item.kind {
        case .nativeAgentList:
            ServerDetailView(profile: server)
        case .nativeAgentManage:
            AdminAgentManageView(server: server)
        case .nativeBilling:
            BillingOverviewView()
        case .nativeCron:
            AdminCronListView(server: server)
        case .nativeToken:
            AdminTokenListView(server: server)
        case .nativeKV:
            AdminKVNamespaceView(server: server)
        case .nativeWorker:
            AdminWorkersView(server: server)
        case .nativeBatch:
            AdminBatchExecuteView(server: server)
        case .nativeSettings:
            SettingsView()
        case .nativeAbout:
            DashboardAboutNativeView()
        case .scriptSnippet:
            AdminKVEntryView(server: server, namespace: "script_snippet")
        case .web(let route):
            DashboardWebBridgeView(server: server, route: route, title: item.title)
        case .nodePicker(let template):
            DashboardNodePickerView(server: server, title: item.title, routeTemplate: template)
        }
    }
}

struct DashboardNodePickerView: View {
    let server: ServerProfile
    let title: String
    let routeTemplate: String

    @State private var rows: [AdminAgentRow] = []
    @State private var message = "正在读取节点…"
    @State private var isLoading = false

    var body: some View {
        AdminListPage(title: title, message: message, loading: isLoading) {
            if rows.isEmpty && !isLoading { AdminEmptyCard(text: "暂无节点。") }
            ForEach(rows) { row in
                NavigationLink {
                    DashboardWebBridgeView(server: server, route: String(format: routeTemplate, row.uuid), title: "\(row.displayName) · \(title)")
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(row.displayName)
                                .font(.headline.weight(.black))
                                .foregroundStyle(Color.ngText)
                            Text(row.uuid)
                                .font(.caption.monospaced())
                                .foregroundStyle(Color.ngMuted)
                                .lineLimit(1)
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
            let uuids = try await client.listAllAgentUUIDs(token: token).sorted()
            let staticMap = (try? await client.latestStaticInfoMap(token: token, uuids: uuids)) ?? [:]
            let metaMap = (try? await client.metadataMap(token: token, uuids: uuids)) ?? [:]
            rows = uuids.map { uuid in AdminAgentRow(uuid: uuid, meta: metaMap[uuid], staticInfo: staticMap[uuid]) }
            message = "选择一个节点打开 \(title)。"
        } catch {
            message = "读取失败：\(error.localizedDescription)"
        }
    }
}

struct DashboardWebBridgeView: View {
    let server: ServerProfile
    let route: String
    let title: String

    @State private var token = ""

    var body: some View {
        Group {
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

struct DashboardAboutNativeView: View {
    var body: some View {
        AdminListPage(title: "关于", message: "NodeGet Monitor · v0.8.2", loading: false) {
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
