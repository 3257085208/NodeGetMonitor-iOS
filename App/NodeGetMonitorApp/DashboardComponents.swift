import SwiftUI

struct DashboardAgentCardView: View {
    let summary: AgentSummary
    let staticInfo: StaticAgentInfo?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(Color.green)
                    .frame(width: 10, height: 10)
                    .padding(.top, 5)

                VStack(alignment: .leading, spacing: 4) {
                    Text(staticInfo?.displayName ?? shortUUID(summary.uuid))
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if let staticInfo, !staticInfo.systemLine.isEmpty {
                        Text(staticInfo.systemLine)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else {
                        Text(summary.uuid)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Text(NodeGetFormatters.relativeTime(milliseconds: summary.timestamp))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 18) {
                RingMetricView(title: "CPU", value: NodeGetFormatters.percent(summary.cpuUsage), progress: progress(summary.cpuUsage))
                RingMetricView(title: "内存", value: NodeGetFormatters.percent(summary.memoryUsagePercent), progress: progress(summary.memoryUsagePercent))
                RingMetricView(title: "磁盘", value: NodeGetFormatters.percent(summary.diskUsagePercent), progress: progress(summary.diskUsagePercent))
            }
            .frame(maxWidth: .infinity)

            if let staticInfo, !staticInfo.cpuLine.isEmpty {
                Text(staticInfo.cpuLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            HStack(spacing: 12) {
                SmallMetricColumn(title: "内存", value: "\(NodeGetFormatters.bytes(summary.usedMemory)) / \(NodeGetFormatters.bytes(summary.totalMemory))")
                SmallMetricColumn(title: "磁盘可用", value: NodeGetFormatters.bytes(summary.availableSpace))
            }

            HStack(spacing: 12) {
                SmallMetricColumn(title: "下载", value: NodeGetFormatters.speed(summary.receiveSpeed))
                SmallMetricColumn(title: "上传", value: NodeGetFormatters.speed(summary.transmitSpeed))
            }

            HStack(spacing: 12) {
                SmallMetricColumn(title: "进程", value: summary.processCount.map(String.init) ?? "--")
                SmallMetricColumn(title: "运行时长", value: NodeGetFormatters.uptime(summary.uptime))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(uiColor: .secondarySystemBackground))
        )
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
                    .stroke(Color.gray.opacity(0.15), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.green, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text(value)
                        .font(.subheadline.bold())
                        .monospacedDigit()
                    Text(title)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 78, height: 78)
        }
        .frame(maxWidth: .infinity)
    }
}

struct SmallMetricColumn: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
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
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.largeTitle.bold())
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            HStack(spacing: 10) {
                CountChip(title: "全部", value: agentCount)
                Spacer()
                Button {
                    refreshAction()
                } label: {
                    if loading {
                        ProgressView()
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                    } else {
                        Label("刷新", systemImage: "arrow.clockwise")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                    }
                }
                .buttonStyle(.bordered)
                .tint(.green)
            }

            Text(statusText)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

struct CountChip: View {
    let title: String
    let value: Int

    var body: some View {
        HStack(spacing: 6) {
            Text(title)
            Text("\(value)")
                .fontWeight(.bold)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(Color.green.opacity(0.12)))
        .foregroundStyle(.green)
    }
}
