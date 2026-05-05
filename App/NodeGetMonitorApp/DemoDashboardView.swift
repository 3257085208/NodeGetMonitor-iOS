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
            uptime: 86_400,
            processCount: 132,
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
            uptime: 172_800,
            processCount: 221,
            gpuUsage: nil
        )
    ]

    private let staticMap: [String: StaticAgentInfo] = [
        "demo-tokyo-01": StaticAgentInfo(
            uuid: "demo-tokyo-01",
            timestamp: 1_769_344_160_000,
            cpu: StaticCPUData(
                physicalCores: 4,
                logicalCores: 8,
                perCore: [StaticPerCpuCoreData(id: 1, name: "CPU 1", vendorID: "Intel", brand: "Intel Xeon")]
            ),
            system: StaticSystemData(
                systemName: "Linux",
                systemKernel: nil,
                systemKernelVersion: nil,
                systemOsVersion: nil,
                systemOsLongVersion: "Debian GNU/Linux 12",
                distributionID: "debian",
                systemHostName: "EUserv",
                arch: "x86_64",
                virtualization: "LXC"
            )
        ),
        "demo-la-02": StaticAgentInfo(
            uuid: "demo-la-02",
            timestamp: 1_769_344_160_000,
            cpu: StaticCPUData(
                physicalCores: 2,
                logicalCores: 4,
                perCore: [StaticPerCpuCoreData(id: 1, name: "CPU 1", vendorID: "AMD", brand: "AMD EPYC")]
            ),
            system: StaticSystemData(
                systemName: "Linux",
                systemKernel: nil,
                systemKernelVersion: nil,
                systemOsVersion: nil,
                systemOsLongVersion: "Debian GNU/Linux 12",
                distributionID: "debian",
                systemHostName: "MegaBoxPro",
                arch: "x86_64",
                virtualization: "KVM"
            )
        )
    ]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(demoAgents) { agent in
                    DashboardAgentCardView(summary: agent, staticInfo: staticMap[agent.uuid])
                }
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Demo 仪表盘")
    }
}
