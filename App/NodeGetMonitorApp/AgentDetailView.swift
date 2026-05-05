import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct AgentDetailView: View {
    let server: ServerProfile
    let uuid: String
    let summary: AgentSummary?
    let staticInfo: StaticAgentInfo?

    @State private var copyMessage = ""

    var body: some View {
        List {
            Section("节点信息") {
                LabeledContent("显示名称", value: staticInfo?.displayName ?? shortUUID(uuid))
                LabeledContent("UUID", value: uuid)
                if let staticInfo, !staticInfo.systemLine.isEmpty {
                    LabeledContent("系统", value: staticInfo.systemLine)
                }
                if let staticInfo, !staticInfo.cpuLine.isEmpty {
                    LabeledContent("CPU", value: staticInfo.cpuLine)
                }
            }

            if let summary {
                Section("实时数据") {
                    LabeledContent("CPU", value: NodeGetFormatters.percent(summary.cpuUsage))
                    LabeledContent("内存", value: "\(NodeGetFormatters.bytes(summary.usedMemory)) / \(NodeGetFormatters.bytes(summary.totalMemory))")
                    LabeledContent("磁盘可用", value: NodeGetFormatters.bytes(summary.availableSpace))
                    LabeledContent("下载", value: NodeGetFormatters.speed(summary.receiveSpeed))
                    LabeledContent("上传", value: NodeGetFormatters.speed(summary.transmitSpeed))
                    LabeledContent("运行时长", value: NodeGetFormatters.uptime(summary.uptime))
                    LabeledContent("更新时间", value: NodeGetFormatters.relativeTime(milliseconds: summary.timestamp))
                }
            }

            Section("操作") {
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

            Section("服务器") {
                LabeledContent("名称", value: server.name)
                LabeledContent("地址", value: server.baseURL.absoluteString)
            }
        }
        .navigationTitle(staticInfo?.displayName ?? "Agent")
    }

    private func shortUUID(_ uuid: String) -> String {
        guard uuid.count > 12 else { return uuid }
        return String(uuid.prefix(8)) + "..." + String(uuid.suffix(4))
    }
}
