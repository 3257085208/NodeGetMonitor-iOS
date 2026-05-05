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
        ZStack {
            AppBackgroundView()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    agentHeader

                    if let summary {
                        liveSection(summary)
                    }

                    infoSection
                    actionSection
                    serverSection
                }
                .padding(20)
            }
        }
        .navigationTitle(staticInfo?.displayName ?? "Agent")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var agentHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(Color.ngPrimary)
                            .frame(width: 12, height: 12)
                        Text(staticInfo?.displayName ?? shortUUID(uuid))
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundStyle(Color.black)
                    }

                    Text(staticInfo?.systemLine ?? "未知系统")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.ngMuted)
                }
                Spacer()
                Text(summary.map { NodeGetFormatters.relativeTime(milliseconds: $0.timestamp) } ?? "--")
                    .font(.caption.bold())
                    .foregroundStyle(Color.ngMuted)
            }

            if let summary {
                HStack(spacing: 12) {
                    RingMetricView(title: "CPU", value: NodeGetFormatters.percent(summary.cpuUsage), progress: progress(summary.cpuUsage))
                    RingMetricView(title: "内存", value: NodeGetFormatters.percent(summary.memoryUsagePercent), progress: progress(summary.memoryUsagePercent))
                    RingMetricView(title: "磁盘", value: NodeGetFormatters.percent(summary.diskUsagePercent), progress: progress(summary.diskUsagePercent))
                }
            }
        }
        .padding(20)
        .ngSoftCard()
    }

    private func liveSection(_ summary: AgentSummary) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionCaption(text: "实时数据")
            VStack(spacing: 14) {
                HStack(spacing: 14) {
                    SmallMetricColumn(title: "内存", value: "\(NodeGetFormatters.bytes(summary.usedMemory)) / \(NodeGetFormatters.bytes(summary.totalMemory))")
                    SmallMetricColumn(title: "磁盘可用", value: NodeGetFormatters.bytes(summary.availableSpace))
                }
                HStack(spacing: 14) {
                    SmallMetricColumn(title: "下载", value: NodeGetFormatters.speed(summary.receiveSpeed))
                    SmallMetricColumn(title: "上传", value: NodeGetFormatters.speed(summary.transmitSpeed))
                }
                HStack(spacing: 14) {
                    SmallMetricColumn(title: "运行时长", value: NodeGetFormatters.uptime(summary.uptime))
                    SmallMetricColumn(title: "更新时间", value: NodeGetFormatters.relativeTime(milliseconds: summary.timestamp))
                }
            }
            .padding(18)
            .ngSoftCard()
        }
    }

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionCaption(text: "节点信息")
            VStack(alignment: .leading, spacing: 12) {
                DetailRow(title: "显示名称", value: staticInfo?.displayName ?? shortUUID(uuid))
                DetailRow(title: "UUID", value: uuid, multiline: true)
                if let staticInfo, !staticInfo.systemLine.isEmpty {
                    DetailRow(title: "系统", value: staticInfo.systemLine, multiline: true)
                }
                if let staticInfo, !staticInfo.cpuLine.isEmpty {
                    DetailRow(title: "CPU", value: staticInfo.cpuLine, multiline: true)
                }
            }
            .padding(18)
            .ngSoftCard()
        }
    }

    private var actionSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionCaption(text: "操作")
            VStack(alignment: .leading, spacing: 12) {
                Button {
                    #if canImport(UIKit)
                    UIPasteboard.general.string = uuid
                    #endif
                    copyMessage = "已复制 UUID"
                } label: {
                    Label("复制 UUID", systemImage: "doc.on.doc")
                        .font(.headline)
                        .foregroundStyle(.blue)
                }

                if !copyMessage.isEmpty {
                    Text(copyMessage)
                        .font(.footnote)
                        .foregroundStyle(Color.ngMuted)
                }
            }
            .padding(18)
            .ngSoftCard()
        }
    }

    private var serverSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionCaption(text: "服务器")
            VStack(alignment: .leading, spacing: 12) {
                DetailRow(title: "名称", value: server.name)
                DetailRow(title: "地址", value: server.baseURL.absoluteString, multiline: true)
            }
            .padding(18)
            .ngSoftCard()
        }
    }

    private func progress(_ value: Double?) -> Double {
        guard let value else { return 0 }
        return min(max(value / 100.0, 0), 1)
    }

    private func shortUUID(_ uuid: String) -> String {
        guard uuid.count > 12 else { return uuid }
        return String(uuid.prefix(8)) + "..." + String(uuid.suffix(4))
    }
}

struct DetailRow: View {
    let title: String
    let value: String
    var multiline: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(Color.ngMuted)
            Text(value)
                .font(.headline)
                .foregroundStyle(Color.black)
                .fixedSize(horizontal: false, vertical: multiline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 2)
    }
}
