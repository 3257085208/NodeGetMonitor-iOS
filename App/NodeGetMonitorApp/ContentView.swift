import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var serverStore: ServerProfileStore

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        AddServerView()
                    } label: {
                        Label("添加 NodeGet Server", systemImage: "plus.circle")
                    }

                    NavigationLink {
                        DemoDashboardView()
                    } label: {
                        Label("查看 Demo 仪表盘", systemImage: "chart.line.uptrend.xyaxis")
                    }
                }

                Section("我的服务器") {
                    if serverStore.servers.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("还没有保存服务器")
                                .font(.headline)
                            Text("添加服务器并保存 Token 后，就可以查看真实节点仪表盘。")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 6)
                    } else {
                        ForEach(serverStore.servers) { server in
                            NavigationLink {
                                ServerDetailView(profile: server)
                            } label: {
                                ServerRowView(profile: server)
                            }
                        }
                        .onDelete(perform: serverStore.delete)
                    }
                }

                Section("当前版本") {
                    LabeledContent("App", value: "NodeGet Monitor")
                    LabeledContent("Version", value: "0.3.0")
                    Text("这一版开始把服务器页升级成移动端仪表盘样式，并接入实时 CPU、内存、磁盘、网络和静态系统信息。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("NodeGet Monitor")
        }
    }
}

struct ServerRowView: View {
    let profile: ServerProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(profile.name)
                .font(.headline)
            Text(profile.baseURL.absoluteString)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
    }
}
