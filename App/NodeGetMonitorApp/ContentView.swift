import SwiftUI

struct ContentView: View {
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

                Section("当前版本") {
                    LabeledContent("App", value: "NodeGet Monitor")
                    LabeledContent("Version", value: "0.1.0")
                    Text("这是第一个 GitHub Actions 可打包的原生 SwiftUI 版本。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("NodeGet Monitor")
        }
    }
}
