import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct AgentDetailView: View {
    let server: ServerProfile
    let uuid: String
    let summary: AgentSummary?
    let staticInfo: StaticAgentInfo?
    let meta: AgentMeta?

    @State private var liveSummary: AgentSummary?
    @State private var liveStaticInfo: StaticAgentInfo?
    @State private var liveMeta: AgentMeta?
    @State private var copyMessage = ""
    @State private var history: [AgentSummary] = []
    @State private var pingRows: [TaskQueryResult] = []
    @State private var tcpRows: [TaskQueryResult] = []
    @State private var extraMessage = "正在读取趋势与 Ping 数据…"
    @State private var isLoadingExtra = false
    @State private var isRefreshingExtra = false

    var body: some View {
        ZStack {
            AppBackgroundView()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    agentHeader

                    resourceOverview

                    onlineSection

                    trendSection

                    latencySection(title: "TCP PING · 近 1 小时", rows: tcpRows, type: "tcp_ping")

                    latencySection(title: "PING · 近 1 小时", rows: pingRows, type: "ping")

                    systemAndNetworkSection

                    billingSection

                    actionSection
                }
                .padding(20)
            }
        }
        .navigationTitle(displayName)
        .navigationBarTitleDisplayMode(.inline)
        .task(id: uuid) {
            await loadExtraData()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                guard !Task.isCancelled else { break }
                await loadExtraData(showLoading: false)
            }
        }
        .refreshable {
            await loadExtraData()
        }
    }

    private var currentSummary: AgentSummary? {
        liveSummary ?? summary
    }

    private var currentStaticInfo: StaticAgentInfo? {
        liveStaticInfo ?? staticInfo
    }

    private var currentMeta: AgentMeta? {
        liveMeta ?? meta
    }

    private var displayName: String {
        currentMeta?.name.nilIfEmpty ?? currentStaticInfo?.displayName ?? shortUUID(uuid)
    }

    private var agentHeader: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(isOnline ? Color.ngPrimary : Color.red)
                            .frame(width: 12, height: 12)

                        if let region = currentMeta?.region.nilIfEmpty {
                            Text(region.uppercased())
                                .font(.caption2.weight(.black))
                                .foregroundStyle(Color.ngMuted)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Capsule().fill(Color.ngBackground))
                        }

                        Text(displayName)
                            .font(.system(size: 28, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ngText)
                            .lineLimit(1)
                    }

                    Text(currentStaticInfo?.systemLine ?? "未知系统")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.ngMuted)
                        .lineLimit(2)
                }

                Spacer()

                Text(virtText)
                    .font(.caption.weight(.black))
                    .foregroundStyle(Color.ngText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.ngPrimarySoft))
            }

            if let summary = currentSummary {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ],
                    spacing: 14
                ) {
                    RingMetricView(title: "CPU", value: NodeGetFormatters.percent(summary.cpuUsage), progress: progress(summary.cpuUsage), size: 84)
                    RingMetricView(title: "内存", value: NodeGetFormatters.percent(summary.memoryUsagePercent), progress: progress(summary.memoryUsagePercent), size: 84)
                    RingMetricView(title: "磁盘", value: NodeGetFormatters.percent(summary.diskUsagePercent), progress: progress(summary.diskUsagePercent), size: 84)
                    RingMetricView(title: "Swap", value: NodeGetFormatters.percent(summary.swapUsagePercent), progress: progress(summary.swapUsagePercent), size: 84)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(20)
        .ngSoftCard()
    }

    private var resourceOverview: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionCaption(text: "资源")
            VStack(spacing: 14) {
                HStack(spacing: 14) {
                    SmallMetricColumn(title: "CPU", value: NodeGetFormatters.percent(currentSummary?.cpuUsage))
                    SmallMetricColumn(title: "负载", value: loadText)
                }
                HStack(spacing: 14) {
                    SmallMetricColumn(title: "内存", value: currentSummary?.memoryUsedText ?? "--")
                    SmallMetricColumn(title: "Swap", value: currentSummary?.swapUsedText ?? "--")
                }
                HStack(spacing: 14) {
                    SmallMetricColumn(title: "磁盘", value: currentSummary?.diskUsedText ?? "--")
                    SmallMetricColumn(title: "磁盘可用", value: NodeGetFormatters.bytes(currentSummary?.availableSpace))
                }
            }
            .padding(18)
            .ngSoftCard()
        }
    }

    private var onlineSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionCaption(text: "在线状态")
            OnlineStatusStrip(
                title: "在线状态",
                percent: onlinePercent,
                values: onlineValues
            )
            .ngSoftCard()
        }
    }

    private var trendSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                SectionCaption(text: "近 240 秒趋势")
                if isLoadingExtra {
                    ProgressView()
                }
            }

            let rows = trendRowsForChart
            let times = rows.map { $0.timestamp }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                TrendMetricCard(
                    title: "CPU %",
                    value: NodeGetFormatters.percent(rows.last?.cpuUsage ?? currentSummary?.cpuUsage),
                    values: rows.map { $0.cpuUsage },
                    timestamps: times,
                    color: .blue,
                    valueFormatter: { NodeGetFormatters.percent($0) }
                )
                TrendMetricCard(
                    title: "内存 %",
                    value: NodeGetFormatters.percent(rows.last?.memoryUsagePercent ?? currentSummary?.memoryUsagePercent),
                    values: rows.map { $0.memoryUsagePercent },
                    timestamps: times,
                    color: Color.ngPrimary,
                    valueFormatter: { NodeGetFormatters.percent($0) }
                )
                TrendMetricCard(
                    title: "下行",
                    value: NodeGetFormatters.speed(rows.last?.receiveSpeed ?? currentSummary?.receiveSpeed),
                    values: rows.map { $0.receiveSpeed },
                    timestamps: times,
                    color: .purple,
                    valueFormatter: { NodeGetFormatters.speed($0) }
                )
                TrendMetricCard(
                    title: "上行",
                    value: NodeGetFormatters.speed(rows.last?.transmitSpeed ?? currentSummary?.transmitSpeed),
                    values: rows.map { $0.transmitSpeed },
                    timestamps: times,
                    color: .orange,
                    valueFormatter: { NodeGetFormatters.speed($0) }
                )
            }

            Text(extraMessage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.ngMuted)
        }
    }

    private func latencySection(title: String, rows: [TaskQueryResult], type: String) -> some View {
        let stats = NodeGetStats.latencyStats(rows: rows, type: type, buckets: 60)
        let emptyName = type == "tcp_ping" ? "TCP Ping" : "Ping"
        return VStack(alignment: .leading, spacing: 14) {
            SectionCaption(text: title)

            if stats.isEmpty {
                Text("暂无 \(emptyName) 数据。请确认 Token 拥有 Task::Read 权限，并且服务端已有对应任务结果。")
                    .font(.subheadline)
                    .foregroundStyle(Color.ngMuted)
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .ngSoftCard()
            } else {
                LatencyDashboardPanel(stats: stats, type: type)
                    .ngSoftCard()
            }
        }
    }

    private var systemAndNetworkSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionCaption(text: "系统与网络")
            VStack(spacing: 18) {
                VStack(spacing: 10) {
                    DetailInfoRow(title: "主机名", value: currentStaticInfo?.system?.systemHostName ?? "--")
                    DetailInfoRow(title: "操作系统", value: currentStaticInfo?.system?.systemOsLongVersion ?? currentStaticInfo?.system?.systemName ?? "--")
                    DetailInfoRow(title: "内核", value: currentStaticInfo?.system?.systemKernelVersion ?? currentStaticInfo?.system?.systemKernel ?? "--")
                    DetailInfoRow(title: "CPU 架构", value: currentStaticInfo?.system?.arch ?? "--")
                    DetailInfoRow(title: "虚拟化", value: virtText)
                    DetailInfoRow(title: "CPU 型号", value: currentStaticInfo?.cpu?.perCore.first?.brand ?? "--")
                    DetailInfoRow(title: "核心", value: coreText)
                }

                Divider()

                VStack(spacing: 10) {
                    DetailInfoRow(title: "累计接收", value: NodeGetFormatters.bytes(currentSummary?.totalReceived))
                    DetailInfoRow(title: "累计发送", value: NodeGetFormatters.bytes(currentSummary?.totalTransmitted))
                    DetailInfoRow(title: "磁盘读", value: NodeGetFormatters.speed(currentSummary?.readSpeed))
                    DetailInfoRow(title: "磁盘写", value: NodeGetFormatters.speed(currentSummary?.writeSpeed))
                    DetailInfoRow(title: "进程数", value: currentSummary?.processCount.map(String.init) ?? "--")
                    DetailInfoRow(title: "TCP / UDP", value: "\(currentSummary?.tcpConnections.map(String.init) ?? "--") / \(currentSummary?.udpConnections.map(String.init) ?? "--")")
                    DetailInfoRow(title: "运行时长", value: NodeGetFormatters.uptime(currentSummary?.uptime))
                    DetailInfoRow(title: "数据更新", value: NodeGetFormatters.relativeTime(milliseconds: currentSummary?.timestamp))
                }
            }
            .padding(18)
            .ngSoftCard()
        }
    }

    private var billingSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionCaption(text: "费用")
            VStack(spacing: 12) {
                DetailInfoRow(title: "到期", value: NodeGetFormatters.date(currentMeta?.expiryDate))
                DetailInfoRow(title: "剩余", value: NodeGetFormatters.days(currentMeta?.remainingDays))
                DetailInfoRow(title: "续费价格", value: currentMeta?.displayPrice ?? "--")
                DetailInfoRow(title: "计费周期", value: currentMeta?.cycleText ?? "--")

                GeometryReader { geo in
                    let progress = billingProgress
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4).fill(Color.ngBorder)
                        RoundedRectangle(cornerRadius: 4).fill(Color.ngPrimary)
                            .frame(width: geo.size.width * progress)
                    }
                }
                .frame(height: 8)
                .padding(.top, 4)
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

    private var isOnline: Bool {
        guard let timestamp = currentSummary?.timestamp else { return false }
        return Date().timeIntervalSince1970 * 1000 - Double(timestamp) < 120_000
    }

    private var onlinePercent: Double {
        guard !history.isEmpty else { return isOnline ? 100 : 0 }
        let online = history.filter { row in
            guard let ts = row.timestamp else { return false }
            return Date().timeIntervalSince1970 * 1000 - Double(ts) < 3_600_000
        }
        return Double(online.count) / Double(history.count) * 100
    }

    private var onlineValues: [Bool] {
        let rows = history.suffix(48)
        if rows.isEmpty { return Array(repeating: isOnline, count: 40) }
        let values = rows.map { row in
            guard let ts = row.timestamp else { return false }
            return Date().timeIntervalSince1970 * 1000 - Double(ts) < 3_600_000
        }
        return Array(repeating: true, count: max(0, 48 - values.count)) + values
    }

    private var trendRowsForChart: [AgentSummary] {
        if !history.isEmpty { return history }
        if let currentSummary {
            return Array(repeating: currentSummary, count: 16)
        }
        return []
    }

    private var loadText: String {
        let one = currentSummary?.loadOne.map { String(format: "%.2f", $0) } ?? "--"
        let five = currentSummary?.loadFive.map { String(format: "%.2f", $0) } ?? "--"
        let fifteen = currentSummary?.loadFifteen.map { String(format: "%.2f", $0) } ?? "--"
        return "\(one) / \(five) / \(fifteen)"
    }

    private var virtText: String {
        currentMeta?.virtualization.nilIfEmpty ?? currentStaticInfo?.system?.virtualization ?? "--"
    }

    private var coreText: String {
        let physical = currentStaticInfo?.cpu?.physicalCores.map(String.init) ?? "--"
        let logical = currentStaticInfo?.cpu?.logicalCores.map(String.init) ?? "--"
        return "\(physical) 物理 / \(logical) 逻辑"
    }

    private var billingProgress: Double {
        guard let remaining = currentMeta?.remainingDays, let cycle = currentMeta?.priceCycle, cycle > 0 else { return 0 }
        return min(max(Double(remaining) / Double(cycle), 0), 1)
    }

    private func progress(_ value: Double?) -> Double {
        guard let value else { return 0 }
        return min(max(value / 100.0, 0), 1)
    }

    private func shortUUID(_ uuid: String) -> String {
        guard uuid.count > 12 else { return uuid }
        return String(uuid.prefix(8)) + "..." + String(uuid.suffix(4))
    }

    private func loadExtraData(showLoading: Bool = true) async {
        guard !isRefreshingExtra else { return }

        guard let token = KeychainStore.shared.token(for: server.id) else {
            extraMessage = "未找到 Token，无法读取趋势和 Ping 数据。"
            return
        }

        isRefreshingExtra = true
        if showLoading { isLoadingExtra = true }
        defer {
            isRefreshingExtra = false
            if showLoading { isLoadingExtra = false }
        }

        let client = NodeGetClient(baseURL: server.baseURL)

        var messages: [String] = []

        do {
            let rows = try await client.latestDynamicSummaries(token: token, uuids: [uuid])
            if let latest = rows.first {
                liveSummary = latest
                LocalTrendStore.shared.append(latest)
            }
            history = LocalTrendStore.shared.history(for: uuid)
        } catch {
            messages.append("实时：\(error.localizedDescription)")
            history = LocalTrendStore.shared.history(for: uuid)
        }

        do {
            liveStaticInfo = try await client.latestStaticInfo(token: token, uuid: uuid)
        } catch {
            // 静态信息失败不阻断实时数据刷新
        }

        do {
            let metadata = try await client.metadataMap(token: token, uuids: [uuid])
            liveMeta = metadata[uuid]
        } catch {
            // 元数据失败不阻断实时数据刷新
        }

        if history.count < 3 {
            _ = await loadRemoteHistoryIfAvailable(client: client, token: token)
            history = LocalTrendStore.shared.history(for: uuid)
        }

        switch await loadLatency(client: client, token: token, type: "ping") {
        case .success(let rows):
            pingRows = rows
        case .failure(let error):
            messages.append("Ping：\(error.localizedDescription)")
        }

        switch await loadLatency(client: client, token: token, type: "tcp_ping") {
        case .success(let rows):
            tcpRows = rows
        case .failure(let error):
            messages.append("TCP Ping：\(error.localizedDescription)")
        }

        extraMessage = messages.isEmpty ? "每 2 秒自动刷新于 \(NodeGetFormatters.clockTime(Date()))。" : "部分数据读取失败：" + messages.joined(separator: "；")
    }

    @discardableResult
    private func loadRemoteHistoryIfAvailable(client: NodeGetClient, token: String) async -> Bool {
        do {
            let rows = try await client.dynamicSummaryHistory(
                token: token,
                uuid: uuid,
                limit: 120,
                windowMilliseconds: nil
            )
            if !rows.isEmpty {
                LocalTrendStore.shared.mergeRemote(rows, for: uuid)
                return true
            }
        } catch {
            // 官方 StatusShow 主要使用前端本地采样构建 240 秒趋势；远端历史接口失败时静默降级，避免把 Invalid params 暴露给用户。
        }
        return false
    }

    private func loadLatency(client: NodeGetClient, token: String, type: String) async -> Result<[TaskQueryResult], Error> {
        do {
            let rows = try await client.taskLatencyRows(token: token, uuid: uuid, type: type)
            return .success(rows)
        } catch {
            return .failure(error)
        }
    }
}

struct LatencyDashboardPanel: View {
    let stats: [LatencyStats]
    let type: String

    var body: some View {
        VStack(spacing: 16) {
            MiniLatencyChart(stats: stats)
                .frame(height: 230)

            Divider()

            ScrollView(.horizontal, showsIndicators: false) {
                VStack(spacing: 12) {
                    HStack {
                        tableHeader("来源", width: 160, alignment: .leading)
                        tableHeader("质量", width: 320, alignment: .leading)
                        tableHeader("平均延迟", width: 88)
                        tableHeader("抖动", width: 70)
                        tableHeader("丢包率", width: 70)
                    }

                    ForEach(Array(stats.enumerated()), id: \.offset) { index, item in
                        LatencyTableRow(stats: item, color: lineColor(index))
                    }
                }
                .frame(minWidth: 720, alignment: .leading)
            }
        }
        .padding(16)
    }

    private func tableHeader(_ text: String, width: CGFloat, alignment: Alignment = .trailing) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.ngMuted)
            .frame(width: width, alignment: alignment)
    }

    private func lineColor(_ index: Int) -> Color {
        let colors: [Color] = [.red, .orange, .purple, .blue, .green, .cyan]
        return colors[index % colors.count]
    }
}

struct LatencyTableRow: View {
    let stats: LatencyStats
    let color: Color

    var body: some View {
        HStack(spacing: 0) {
            HStack(spacing: 9) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(color)
                    .frame(width: 18, height: 3)
                Text(stats.name)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.ngText)
                    .lineLimit(1)
            }
            .frame(width: 160, alignment: .leading)

            HStack(spacing: 3) {
                ForEach(Array(stats.values.enumerated()), id: \.offset) { _, value in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(qualityColor(for: value))
                        .frame(width: 3, height: 18)
                }
            }
            .frame(width: 320, alignment: .leading)

            Text(NodeGetFormatters.milliseconds(stats.avg))
                .frame(width: 88, alignment: .trailing)
            Text(NodeGetFormatters.milliseconds(stats.jitter))
                .frame(width: 70, alignment: .trailing)
            Text(NodeGetFormatters.percent(stats.lossRate))
                .frame(width: 70, alignment: .trailing)
                .foregroundStyle(stats.lossRate > 20 ? Color.red : Color.ngText)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(Color.ngText)
    }

    private func qualityColor(for value: Double?) -> Color {
        guard let value else { return .red.opacity(0.8) }
        if value <= 80 { return Color.ngPrimary }
        if value <= 160 { return Color.orange }
        if value <= 260 { return Color.orange.opacity(0.85) }
        return Color.red.opacity(0.8)
    }
}

struct MiniLatencyChart: View {
    let stats: [LatencyStats]

    @State private var selectedIndex: Int?

    var body: some View {
        GeometryReader { geo in
            let leftInset: CGFloat = 44
            let bottomInset: CGFloat = 22
            let plotWidth = max(1, geo.size.width - leftInset)
            let plotHeight = max(1, geo.size.height - bottomInset)
            let maxValue = niceMax(stats.flatMap { $0.values.compactMap { $0 } }.max() ?? 1)

            ZStack(alignment: .topLeading) {
                ForEach(0..<5, id: \.self) { tick in
                    let ratio = CGFloat(tick) / 4.0
                    let y = plotHeight * ratio
                    let value = maxValue * Double(4 - tick) / 4.0

                    Text(NodeGetFormatters.milliseconds(value))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Color.ngMuted)
                        .frame(width: leftInset - 6, alignment: .trailing)
                        .position(x: (leftInset - 6) / 2, y: y + 2)

                    Path { path in
                        path.move(to: CGPoint(x: leftInset, y: y))
                        path.addLine(to: CGPoint(x: geo.size.width, y: y))
                    }
                    .stroke(Color.ngBorder.opacity(tick == 4 ? 0.75 : 0.35), lineWidth: tick == 4 ? 1 : 0.6)
                }

                Path { path in
                    path.move(to: CGPoint(x: leftInset, y: 0))
                    path.addLine(to: CGPoint(x: leftInset, y: plotHeight))
                }
                .stroke(Color.ngMuted.opacity(0.55), lineWidth: 1)

                ForEach(Array(stats.enumerated()), id: \.offset) { index, stat in
                    Path { path in
                        var moved = false
                        for (i, value) in stat.values.enumerated() {
                            guard let value else { continue }
                            let x = leftInset + plotWidth * CGFloat(i) / CGFloat(max(stat.values.count - 1, 1))
                            let y = plotHeight - plotHeight * CGFloat(value / maxValue)
                            let p = CGPoint(x: x, y: y)
                            if moved {
                                path.addLine(to: p)
                            } else {
                                path.move(to: p)
                                moved = true
                            }
                        }
                    }
                    .stroke(color(index), style: StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round))
                }

                if let first = timestamp(at: 0) {
                    xAxisLabel(NodeGetFormatters.clockTime(milliseconds: first), x: leftInset, y: plotHeight + 14)
                }
                if let lastIndex = maxIndex, let last = timestamp(at: lastIndex) {
                    xAxisLabel(NodeGetFormatters.clockTime(milliseconds: last), x: geo.size.width - 24, y: plotHeight + 14)
                }

                if let selected = selectedIndex {
                    let x = xPosition(index: selected, leftInset: leftInset, width: plotWidth)
                    Path { path in
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: plotHeight))
                    }
                    .stroke(Color.ngMuted.opacity(0.45), lineWidth: 1)

                    ForEach(Array(stats.enumerated()), id: \.offset) { index, stat in
                        if let point = pointPosition(stat: stat, index: selected, maxValue: maxValue, leftInset: leftInset, plotWidth: plotWidth, plotHeight: plotHeight) {
                            Circle()
                                .fill(color(index))
                                .frame(width: 7, height: 7)
                                .position(point)
                        }
                    }

                    LatencyTooltipView(
                        time: NodeGetFormatters.clockTime(milliseconds: timestamp(at: selected)),
                        rows: tooltipRows(index: selected)
                    )
                    .position(x: tooltipX(x, width: geo.size.width), y: 38)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        selectedIndex = nearestIndex(locationX: gesture.location.x - leftInset, width: plotWidth)
                    }
                    .onEnded { _ in
                        selectedIndex = nil
                    }
            )
        }
    }

    private var maxIndex: Int? {
        let count = stats.map { $0.values.count }.max() ?? 0
        return count > 0 ? count - 1 : nil
    }

    private func xAxisLabel(_ text: String, x: CGFloat, y: CGFloat) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(Color.ngMuted)
            .position(x: x, y: y)
    }

    private func niceMax(_ value: Double) -> Double {
        let base = max(value, 1)
        if base <= 100 { return 100 }
        if base <= 200 { return 240 }
        if base <= 320 { return 320 }
        if base <= 500 { return 500 }
        return ceil(base / 250) * 250
    }

    private func nearestIndex(locationX: CGFloat, width: CGFloat) -> Int {
        let count = stats.map { $0.values.count }.max() ?? 0
        guard count > 1, width > 0 else { return 0 }
        let ratio = min(max(locationX / width, 0), 1)
        return min(max(Int(round(ratio * CGFloat(count - 1))), 0), count - 1)
    }

    private func xPosition(index: Int, leftInset: CGFloat, width: CGFloat) -> CGFloat {
        let count = stats.map { $0.values.count }.max() ?? 0
        guard count > 1 else { return leftInset + width / 2 }
        return leftInset + width * CGFloat(index) / CGFloat(count - 1)
    }

    private func pointPosition(stat: LatencyStats, index: Int, maxValue: Double, leftInset: CGFloat, plotWidth: CGFloat, plotHeight: CGFloat) -> CGPoint? {
        guard index >= 0, index < stat.values.count, let value = stat.values[index] else { return nil }
        let x = xPosition(index: index, leftInset: leftInset, width: plotWidth)
        let y = plotHeight - plotHeight * CGFloat(value / maxValue)
        return CGPoint(x: x, y: y)
    }

    private func timestamp(at index: Int) -> Int64? {
        for stat in stats {
            if index >= 0, index < stat.timestamps.count, let timestamp = stat.timestamps[index] {
                return timestamp
            }
        }
        return nil
    }

    private func tooltipRows(index: Int) -> [(name: String, value: String, color: Color)] {
        stats.enumerated().map { offset, stat in
            let value: Double? = (index >= 0 && index < stat.values.count) ? stat.values[index] : nil
            return (stat.name, NodeGetFormatters.milliseconds(value), color(offset))
        }
    }

    private func tooltipX(_ x: CGFloat, width: CGFloat) -> CGFloat {
        min(max(x, 96), max(96, width - 96))
    }

    private func color(_ index: Int) -> Color {
        let colors: [Color] = [.red, .orange, .purple, .blue, .green, .cyan]
        return colors[index % colors.count]
    }
}

struct LatencyTooltipView: View {
    let time: String
    let rows: [(name: String, value: String, color: Color)]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(time)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.ngMuted)
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: 5) {
                    Circle()
                        .fill(row.color)
                        .frame(width: 6, height: 6)
                    Text("\(row.name)：\(row.value)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(row.color)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.12), radius: 8, x: 0, y: 4)
        )
        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).stroke(Color.ngBorder, lineWidth: 1))
    }
}
