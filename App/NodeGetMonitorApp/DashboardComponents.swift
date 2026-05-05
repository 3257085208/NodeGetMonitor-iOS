import SwiftUI

struct DashboardAgentCardView: View {
    let summary: AgentSummary
    let staticInfo: StaticAgentInfo?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(Color.ngPrimary)
                    .frame(width: 12, height: 12)
                    .padding(.top, 4)

                VStack(alignment: .leading, spacing: 6) {
                    Text(displayName)
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(Color.black)
                        .lineLimit(1)

                    Text(systemLine)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.ngMuted)
                        .lineLimit(1)
                }

                Spacer()

                Text(NodeGetFormatters.relativeTime(milliseconds: summary.timestamp))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.ngMuted)
            }

            HStack(spacing: 12) {
                RingMetricView(title: "CPU", value: NodeGetFormatters.percent(summary.cpuUsage), progress: progress(summary.cpuUsage))
                RingMetricView(title: "内存", value: NodeGetFormatters.percent(summary.memoryUsagePercent), progress: progress(summary.memoryUsagePercent))
                RingMetricView(title: "磁盘", value: NodeGetFormatters.percent(summary.diskUsagePercent), progress: progress(summary.diskUsagePercent))
            }
            .frame(maxWidth: .infinity)

            Text(cpuLine)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.ngMuted)
                .lineLimit(1)

            metricGrid

            bottomBar
        }
        .padding(18)
        .ngSoftCard()
    }

    private var displayName: String {
        staticInfo?.displayName.lowercased() ?? shortUUID(summary.uuid)
    }

    private var systemLine: String {
        if let staticInfo, !staticInfo.systemLine.isEmpty {
            return staticInfo.systemLine.lowercased()
        }
        return summary.uuid
    }

    private var cpuLine: String {
        if let staticInfo, !staticInfo.cpuLine.isEmpty {
            return staticInfo.cpuLine
        }
        return "暂无 CPU 信息"
    }

    private var metricGrid: some View {
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
                SmallMetricColumn(title: "进程", value: summary.processCount.map(String.init) ?? "--")
                SmallMetricColumn(title: "运行时长", value: NodeGetFormatters.uptime(summary.uptime))
            }
        }
    }

    private var bottomBar: some View {
        HStack {
            Label(summary.gpuUsage == nil ? "无 GPU" : "GPU \(NodeGetFormatters.percent(summary.gpuUsage))", systemImage: "bolt.horizontal.circle")
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.ngMuted)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.headline)
                .foregroundStyle(Color.ngMuted.opacity(0.75))
        }
        .padding(.top, 4)
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

struct RingMetricView: View {
    let title: String
    let value: String
    let progress: Double

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.ngBorder, lineWidth: 8)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.ngPrimary, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text(value)
                        .font(.title3.bold())
                        .foregroundStyle(Color.black)
                        .monospacedDigit()
                        .minimumScaleFactor(0.7)
                    Text(title)
                        .font(.caption.bold())
                        .foregroundStyle(Color.ngMuted)
                }
            }
            .frame(width: 84, height: 84)
        }
        .frame(maxWidth: .infinity)
    }
}

struct SmallMetricColumn: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(Color.ngMuted)
            Text(value)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .foregroundStyle(Color.black)
                .lineLimit(1)
                .minimumScaleFactor(0.68)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ServerSummaryHeaderView: View {
    let title: String
    let subtitle: String
    let statusText: String
    let agentCount: Int
    let loading: Bool
    let refreshAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(size: 32, weight: .black, design: .rounded))
                .foregroundStyle(Color.black)
                .lineLimit(2)
                .minimumScaleFactor(0.7)

            Text(subtitle)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.ngMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            HStack(alignment: .center) {
                DashboardPill(title: "全部", value: "\(agentCount)")
                Spacer()
                Button {
                    refreshAction()
                } label: {
                    HStack(spacing: 10) {
                        if loading {
                            ProgressView()
                                .tint(Color.ngPrimary)
                        } else {
                            Image(systemName: "arrow.clockwise")
                                .font(.title3.weight(.bold))
                        }
                        Text(loading ? "刷新中" : "刷新")
                            .font(.title3.bold())
                    }
                    .foregroundStyle(Color.ngPrimary)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(Color.ngPrimarySoft)
                    )
                }
            }

            Text(statusText)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.ngMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
