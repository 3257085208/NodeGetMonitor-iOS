import SwiftUI

private enum HomeMenuSheet: String, Identifiable {
    case settings
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

                if let primaryServer = serverStore.servers.first {
                    HomeDashboardView(profile: primaryServer)
                        .id(primaryServer.id)
                } else {
                    EmptyHomeView(openSettings: { activeSheet = .settings })
                }
            }
            .navigationTitle("NodeGet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            activeSheet = .settings
                        } label: {
                            Label("设置", systemImage: "gearshape")
                        }

                        Button {
                            activeSheet = .about
                        } label: {
                            Label("关于", systemImage: "info.circle")
                        }

                        Button {
                            activeSheet = .privacy
                        } label: {
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
                    SettingsView()
                        .environmentObject(serverStore)
                case .about:
                    AboutView()
                case .privacy:
                    PrivacyView()
                }
            }
        }
    }
}

struct HomeDashboardView: View {
    @StateObject private var store: ServerDashboardDataStore
    @State private var searchText = ""

    init(profile: ServerProfile) {
        _store = StateObject(wrappedValue: ServerDashboardDataStore(profile: profile))
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                header

                if store.filteredSummaries(searchText: searchText).isEmpty {
                    emptyView
                } else {
                    agentCards
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 32)
        }
        .searchable(text: $searchText, prompt: "搜索节点…")
        .task(id: store.profile.id) {
            await store.refresh()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard !Task.isCancelled else { break }
                await store.refresh(showLoading: false)
            }
        }
        .refreshable {
            await store.refresh()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("NodeGet")
                .font(.system(size: 38, weight: .black, design: .rounded))
                .foregroundStyle(Color.black)

            HStack(spacing: 10) {
                DashboardPill(title: "全部", value: "\(store.summaries.count)")
                DashboardPill(title: store.profile.name, value: "", active: false)
            }

            HStack(alignment: .center, spacing: 12) {
                Text(store.serverMessage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.ngMuted)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)

                Button {
                    Task { await store.refresh() }
                } label: {
                    if store.isLoading {
                        ProgressView()
                            .tint(Color.ngPrimary)
                            .frame(width: 42, height: 42)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Color.ngPrimary)
                            .frame(width: 42, height: 42)
                    }
                }
                .background(Circle().fill(Color.ngPrimarySoft))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(store.isLoading ? "正在读取 Agent…" : "暂无 Agent 数据")
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(Color.ngText)
            Text("首页会自动显示当前主控下的 Agent 卡片。下拉或等待 2 秒会自动刷新。")
                .font(.subheadline)
                .foregroundStyle(Color.ngMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .ngSoftCard()
    }

    private var agentCards: some View {
        ForEach(store.filteredSummaries(searchText: searchText)) { summary in
            NavigationLink {
                AgentDetailView(
                    server: store.profile,
                    uuid: summary.uuid,
                    summary: summary,
                    staticInfo: store.staticInfoByUUID[summary.uuid],
                    meta: store.metaByUUID[summary.uuid]
                )
            } label: {
                DashboardAgentCardView(
                    summary: summary,
                    staticInfo: store.staticInfoByUUID[summary.uuid],
                    meta: store.metaByUUID[summary.uuid]
                )
            }
            .buttonStyle(.plain)
        }
    }
}

struct EmptyHomeView: View {
    let openSettings: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("NodeGet")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundStyle(Color.black)

                VStack(alignment: .leading, spacing: 12) {
                    Text("还没有配置主控")
                        .font(.title2.bold())
                    Text("点右上角菜单进入设置，添加 NodeGet Server 地址和 Token。配置完成后，首页会直接显示 Agent 列表。")
                        .font(.subheadline)
                        .foregroundStyle(Color.ngMuted)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        openSettings()
                    } label: {
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
                            AddServerView()
                                .environmentObject(serverStore)
                        } label: {
                            HomeActionCard(
                                icon: "plus.circle.fill",
                                title: "添加主控",
                                subtitle: "配置 NodeGet Server 地址与 Token"
                            )
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
                                            Text(server.name)
                                                .font(.headline)
                                                .foregroundStyle(Color.ngText)
                                            Text(server.baseURL.absoluteString)
                                                .font(.caption)
                                                .foregroundStyle(Color.ngMuted)
                                                .lineLimit(1)
                                        }
                                        Spacer()
                                        Button(role: .destructive) {
                                            serverStore.delete(server)
                                        } label: {
                                            Image(systemName: "trash")
                                        }
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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
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
                        DetailInfoRow(title: "版本", value: "0.4.7")
                        DetailInfoRow(title: "刷新", value: "首页与详情页每 2 秒自动刷新")
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
                Text(title)
                    .font(.title3.bold())
                    .foregroundStyle(Color.black)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(Color.ngMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.headline)
                .foregroundStyle(Color.ngMuted.opacity(0.8))
        }
        .padding(18)
        .ngSoftCard()
    }
}
