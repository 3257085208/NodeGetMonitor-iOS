import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var serverStore: ServerProfileStore

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView()

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        heroSection

                        quickActionsSection

                        serversSection

                        versionSection
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("NodeGet Monitor")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("NodeGet Monitor")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(Color.black)

            Text("把 NodeGet Server 的 Agent 数据做成更适合 iPhone 的轻量监控仪表盘。")
                .font(.subheadline)
                .foregroundStyle(Color.ngMuted)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                DashboardPill(title: "服务器", value: "\(serverStore.servers.count)")
                DashboardPill(title: "模式", value: "iPhone", active: false)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionCaption(text: "快速开始")

            VStack(spacing: 12) {
                NavigationLink {
                    AddServerView()
                } label: {
                    HomeActionCard(
                        icon: "plus.circle.fill",
                        title: "添加 NodeGet Server",
                        subtitle: "保存 URL 与 Token，接入你的真实 Agent 数据"
                    )
                }
                .buttonStyle(.plain)

                NavigationLink {
                    DemoDashboardView()
                } label: {
                    HomeActionCard(
                        icon: "chart.line.uptrend.xyaxis.circle.fill",
                        title: "查看 Demo 仪表盘",
                        subtitle: "先看 UI 效果，再决定要不要继续做更多细节"
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var serversSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionCaption(text: "我的服务器")

            if serverStore.servers.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("还没有保存服务器")
                        .font(.title3.bold())
                    Text("先添加一个 NodeGet Server。保存后，首页会显示你的服务器卡片，点进去就是监控仪表盘。")
                        .font(.subheadline)
                        .foregroundStyle(Color.ngMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(20)
                .ngSoftCard()
            } else {
                VStack(spacing: 12) {
                    ForEach(serverStore.servers) { server in
                        NavigationLink {
                            ServerDetailView(profile: server)
                        } label: {
                            ServerOverviewCard(profile: server)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(role: .destructive) {
                                serverStore.delete(server)
                            } label: {
                                Label("删除服务器", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }

    private var versionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionCaption(text: "当前版本")

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("App")
                        .font(.headline)
                    Spacer()
                    Text("NodeGet Monitor")
                        .font(.headline)
                        .foregroundStyle(Color.ngMuted)
                }

                Divider()

                HStack {
                    Text("Version")
                        .font(.headline)
                    Spacer()
                    Text("0.4.3")
                        .font(.headline)
                        .foregroundStyle(Color.ngMuted)
                }

                Divider()

                Text("这一版开始接入趋势、Ping/TCP Ping、在线状态、费用元数据等 Dashboard 模块，继续向 StatusShow 前端风格靠近。")
                    .font(.subheadline)
                    .foregroundStyle(Color.ngMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
            .ngSoftCard()
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

struct ServerOverviewCard: View {
    let profile: ServerProfile

    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text(profile.name)
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(Color.black)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                Text(profile.baseURL.absoluteString)
                    .font(.subheadline)
                    .foregroundStyle(Color.ngMuted)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.headline)
                .foregroundStyle(Color.ngMuted.opacity(0.8))
        }
        .padding(20)
        .ngSoftCard()
    }
}
