import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct AgentDetailView: View {
    let server: ServerProfile
    let uuid: String

    @State private var copyMessage = ""

    var body: some View {
        List {
            Section("Agent UUID") {
                Text(uuid)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)

                Button {
                    #if canImport(UIKit)
                    UIPasteboard.general.string = uuid
                    #endif
                    copyMessage = "已复制 UUID"
                } label: {
                    Label("复制 UUID", systemImage: "doc.on.doc")
                }

                if !copyMessage.isEmpty {
                    Text(copyMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("下一步") {
                Text("v0.2 已经接入真实 Agent UUID 列表。v0.3 会在这里调用 agent_dynamic_summary_multi_last_query，显示真实 CPU、内存、磁盘、网络和 GPU 数据。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("服务器") {
                LabeledContent("名称", value: server.name)
                LabeledContent("地址", value: server.baseURL.absoluteString)
            }
        }
        .navigationTitle("Agent")
    }
}
