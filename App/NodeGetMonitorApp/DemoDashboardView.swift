import SwiftUI

struct DemoDashboardView: View {
    private let demoAgents: [AgentSummary] = [
        AgentSummary(
            uuid: "demo-tokyo-01",
            timestamp: 1_769_344_160_000,
            cpuUsage: 12.4,
            usedMemory: 3_200_000_000,
            totalMemory: 8_000_000_000,
            availableMemory: 4_800_000_000,
            totalSpace: 80_000_000_000,
            availableSpace: 41_000_000_000,
            receiveSpeed: 8_500_000,
            transmitSpeed: 1_200_000,
            gpuUsage: 5.0
        ),
        AgentSummary(
            uuid: "demo-la-02",
            timestamp: 1_769_344_160_000,
            cpuUsage: 37.8,
            usedMemory: 6_100_000_000,
            totalMemory: 16_000_000_000,
            availableMemory: 9_900_000_000,
            totalSpace: 160_000_000_000,
            availableSpace: 92_000_000_000,
            receiveSpeed: 2_400_000,
            transmitSpeed: 3_100_000,
            gpuUsage: nil
        )
    ]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(demoAgents) { agent in
                    AgentCardView(agent: agent)
                }
            }
            .padding()
        }
        .navigationTitle("Demo 仪表盘")
    }
}

struct AgentCardView: View {
    let agent: AgentSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(agent.uuid)
                        .font(.headline)
                    Text("在线 · Demo 数据")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(NodeGetFormatters.percent(agent.cpuUsage))
                    .font(.title2.bold())
            }

            Divider()

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                GridRow {
                    MetricLabel(title: "CPU", value: NodeGetFormatters.percent(agent.cpuUsage))
                    MetricLabel(title: "GPU", value: NodeGetFormatters.percent(agent.gpuUsage))
                }

                GridRow {
                    MetricLabel(
                        title: "内存",
                        value: "\(NodeGetFormatters.bytes(agent.usedMemory)) / \(NodeGetFormatters.bytes(agent.totalMemory))"
                    )
                    MetricLabel(
                        title: "磁盘可用",
                        value: NodeGetFormatters.bytes(agent.availableSpace)
                    )
                }

                GridRow {
                    MetricLabel(title: "下载", value: NodeGetFormatters.speed(agent.receiveSpeed))
                    MetricLabel(title: "上传", value: NodeGetFormatters.speed(agent.transmitSpeed))
                }
            }
        }
        .padding()
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct MetricLabel: View {
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
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
