import SwiftUI

struct DashboardAgentCardView: View {
    let summary: AgentSummary
    let staticInfo: StaticAgentInfo?
    let meta: AgentMeta?

    init(summary: AgentSummary, staticInfo: StaticAgentInfo?, meta: AgentMeta? = nil) {
        self.summary = summary
        self.staticInfo = staticInfo
        self.meta = meta
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            HStack(spacing: 12) {
                RingMetricView(title: "CPU", value: NodeGetFormatters.percent(summary.cpuUsage), progress: progress(summary.cpuUsage), size: 72)
                RingMetricView(title: "内存", value: NodeGetFormatters.percent(summary.memoryUsagePercent), progress: progress(summary.memoryUsagePercent), size: 72)
                RingMetricView(title: "磁盘", value: NodeGetFormatters.percent(summary.diskUsagePercent), progress: progress(summary.diskUsagePercent), size: 72)
            }

            Text(cpuLine)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.ngMuted)
                .lineLimit(1)

            OnlineStatusStrip(title: "在线状态", percent: isOnline ? 100 : 0, values: Array(repeating: isOnline, count: 40))

            metricGrid

            HStack {
                Label(NodeGetFormatters.speed(summary.receiveSpeed), systemImage: "arrow.down")
                Label(NodeGetFormatters.speed(summary.transmitSpeed), systemImage: "arrow.up")
                Spacer()
                Text(NodeGetFormatters.relativeTime(milliseconds: summary.timestamp))
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.ngMuted)
            .padding(.top, 2)
        }
        .padding(18)
        .ngSoftCard()
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Circle()
                .fill(isOnline ? Color.ngPrimary : Color.red)
                .frame(width: 10, height: 10)

            Text(meta?.name.nilIfEmpty ?? staticInfo?.displayName ?? shortUUID(summary.uuid))
                .font(.system(size: 20, weight: .black, design: .rounded))
                .foregroundStyle(Color.ngText)
                .lineLimit(1)

            Spacer()

            if let region = meta?.region, !region.isEmpty {
                Text(region.uppercased())
                    .font(.caption2.weight(.black))
                    .foregroundStyle(Color.ngMuted)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.ngBackground))
            }

            if let virt = virtualizationText.nilIfEmpty {
                Text(virt.uppercased())
                    .font(.caption2.weight(.black))
                    .foregroundStyle(Color.ngText)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.ngPrimarySoft))
            }
        }
    }

    private var metricGrid: some View {
        VStack(spacing: 12) {
            HStack(spacing: 14) {
                SmallMetricColumn(title: "内存", value: summary.memoryUsedText)
                SmallMetricColumn(title: "磁盘可用", value: NodeGetFormatters.bytes(summary.availableSpace))
            }
            HStack(spacing: 14) {
                SmallMetricColumn(title: "进程", value: summary.processCount.map(String.init) ?? "--")
                SmallMetricColumn(title: "运行时长", value: NodeGetFormatters.uptime(summary.uptime))
            }
        }
    }

    private var isOnline: Bool {
        guard let timestamp = summary.timestamp else { return false }
        return Date().timeIntervalSince1970 * 1000 - Double(timestamp) < 120_000
    }

    private var virtualizationText: String {
        if let v = meta?.virtualization.nilIfEmpty { return v }
        return staticInfo?.system?.virtualization ?? ""
    }

    private var systemLine: String {
        if let staticInfo, !staticInfo.systemLine.isEmpty { return staticInfo.systemLine.lowercased() }
        return summary.uuid
    }

    private var cpuLine: String {
        if let staticInfo, !staticInfo.cpuLine.isEmpty { return staticInfo.cpuLine }
        return "暂无 CPU 信息"
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
    var size: CGFloat = 92

    @State private var animatedProgress: Double = 0
    @State private var previousProgress: Double = 0
    @State private var flashScale: CGFloat = 1

    private var ringColor: Color {
        metricColor(for: progress)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.ngBorder, lineWidth: size > 80 ? 9 : 7)

            Circle()
                .trim(from: 0, to: animatedProgress)
                .stroke(ringColor, style: StrokeStyle(lineWidth: size > 80 ? 9 : 7, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .shadow(color: ringColor.opacity(0.26), radius: size > 80 ? 16 : 12, x: 0, y: 7)

            Circle()
                .fill(Color.white)
                .padding(size > 80 ? 20 : 16)
                .shadow(color: Color.ngBorder.opacity(0.7), radius: 0, x: 0, y: 0)

            VStack(spacing: 2) {
                Text(value)
                    .font(size > 80 ? .title3.bold() : .subheadline.bold())
                    .foregroundStyle(valueColor)
                    .monospacedDigit()
                    .minimumScaleFactor(0.62)
                    .scaleEffect(flashScale)
                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(Color.ngMuted)
            }
        }
        .frame(width: size, height: size)
        .frame(maxWidth: .infinity)
        .onAppear {
            previousProgress = progress
            withAnimation(.easeOut(duration: 0.9)) {
                animatedProgress = clampedProgress(progress)
            }
        }
        .onChange(of: progress) { _, newValue in
            let delta = abs(newValue - previousProgress)
            let duration = max(0.22, min(0.9, 0.95 - delta * 0.55))
            previousProgress = newValue
            withAnimation(.easeOut(duration: duration)) {
                animatedProgress = clampedProgress(newValue)
            }
            withAnimation(.interpolatingSpring(stiffness: 260, damping: 15)) {
                flashScale = 1.08
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                withAnimation(.easeOut(duration: 0.22)) {
                    flashScale = 1
                }
            }
        }
    }

    private var valueColor: Color {
        if progress >= 0.9 { return .red }
        if progress >= 0.7 { return .orange }
        return Color.ngText
    }

    private func clampedProgress(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }

    private func metricColor(for value: Double) -> Color {
        if value >= 0.9 { return .red }
        if value >= 0.7 { return .orange }
        return Color.ngPrimary
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
                .font(.system(size: 17, weight: .black, design: .rounded))
                .foregroundStyle(Color.ngText)
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
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.ngMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct OnlineStatusStrip: View {
    let title: String
    let percent: Double
    let values: [Bool]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(title, systemImage: "waveform.path.ecg")
                    .foregroundStyle(Color.ngPrimary)
                    .font(.subheadline.bold())
                Spacer()
                Text(NodeGetFormatters.percent(percent))
                    .foregroundStyle(Color.ngPrimary)
                    .font(.subheadline.bold())
            }

            HStack(spacing: 3) {
                ForEach(Array(values.enumerated()), id: \.offset) { _, online in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(online ? Color.ngPrimary : Color.red.opacity(0.65))
                        .frame(height: 28)
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.ngBackground.opacity(0.75)))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.ngBorder, style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
    }
}

struct MiniSparkline: View {
    let values: [Double?]
    let lineColor: Color
    var fill: Bool = false

    var body: some View {
        GeometryReader { geo in
            let valid = values.compactMap { $0 }
            let minValue = valid.min() ?? 0
            let maxValue = valid.max() ?? 1
            let span = max(maxValue - minValue, 1)

            Path { path in
                var didMove = false
                for (index, value) in values.enumerated() {
                    guard let value else { continue }
                    let x = geo.size.width * CGFloat(index) / CGFloat(max(values.count - 1, 1))
                    let y = geo.size.height - geo.size.height * CGFloat((value - minValue) / span)
                    let point = CGPoint(x: x, y: y)
                    if didMove {
                        path.addLine(to: point)
                    } else {
                        path.move(to: point)
                        didMove = true
                    }
                }
            }
            .stroke(lineColor, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
        .frame(height: 52)
    }
}

struct TrendMetricCard: View {
    let title: String
    let value: String
    let values: [Double?]
    let timestamps: [Int64?]
    let color: Color
    var valueFormatter: (Double?) -> String = { NodeGetFormatters.percent($0) }

    @State private var selectedIndex: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.caption.bold())
                    .foregroundStyle(Color.ngMuted)
                Spacer()
                Text(value)
                    .font(.caption.bold())
                    .foregroundStyle(Color.ngText)
            }

            interactiveSparkline
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.ngBorder, lineWidth: 1))
    }

    private var interactiveSparkline: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                MiniSparkline(values: values, lineColor: color)

                if let selected = selectedIndex, selected < values.count {
                    let x = xPosition(index: selected, width: geo.size.width)
                    Path { path in
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: geo.size.height))
                    }
                    .stroke(Color.ngMuted.opacity(0.45), lineWidth: 1)

                    if let point = pointPosition(index: selected, size: geo.size) {
                        Circle()
                            .fill(color)
                            .frame(width: 8, height: 8)
                            .position(point)
                    }

                    TrendTooltipView(
                        time: NodeGetFormatters.clockTime(milliseconds: timestamp(at: selected)),
                        title: title,
                        value: valueFormatter(values[selected]),
                        color: color
                    )
                    .position(x: tooltipX(x, width: geo.size.width), y: 8)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        selectedIndex = nearestIndex(locationX: gesture.location.x, width: geo.size.width)
                    }
                    .onEnded { _ in
                        selectedIndex = nil
                    }
            )
        }
        .frame(height: 72)
    }

    private func timestamp(at index: Int) -> Int64? {
        guard index >= 0, index < timestamps.count else { return nil }
        return timestamps[index]
    }

    private func nearestIndex(locationX: CGFloat, width: CGFloat) -> Int {
        guard values.count > 1, width > 0 else { return 0 }
        let ratio = min(max(locationX / width, 0), 1)
        return min(max(Int(round(ratio * CGFloat(values.count - 1))), 0), values.count - 1)
    }

    private func xPosition(index: Int, width: CGFloat) -> CGFloat {
        guard values.count > 1 else { return width / 2 }
        return width * CGFloat(index) / CGFloat(values.count - 1)
    }

    private func pointPosition(index: Int, size: CGSize) -> CGPoint? {
        guard let value = values[index] else { return nil }
        let valid = values.compactMap { $0 }
        let minValue = valid.min() ?? 0
        let maxValue = valid.max() ?? 1
        let span = max(maxValue - minValue, 1)
        let x = xPosition(index: index, width: size.width)
        let y = size.height - size.height * CGFloat((value - minValue) / span)
        return CGPoint(x: x, y: y)
    }

    private func tooltipX(_ x: CGFloat, width: CGFloat) -> CGFloat {
        min(max(x, 70), max(70, width - 70))
    }
}

struct TrendTooltipView: View {
    let time: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(time)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.ngMuted)
            Text("\(title)：\(value)")
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
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

struct LatencyQualityRowView: View {
    let stats: LatencyStats
    let type: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(stats.name)
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.ngText)
                    .lineLimit(1)
                Spacer()
                Text(NodeGetFormatters.milliseconds(stats.avg))
                    .font(.subheadline.bold())
                    .foregroundStyle(Color.ngText)
            }

            HStack(spacing: 3) {
                ForEach(Array(stats.values.enumerated()), id: \.offset) { _, value in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color(for: value))
                        .frame(height: 18)
                }
            }

            HStack {
                Text("抖动 \(NodeGetFormatters.milliseconds(stats.jitter))")
                Spacer()
                Text("丢包 \(NodeGetFormatters.percent(stats.lossRate))")
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(Color.ngMuted)
        }
    }

    private func color(for value: Double?) -> Color {
        guard let value else { return .red }
        if value <= 45 { return Color.green }
        if value <= 90 { return Color(red: 132/255, green: 204/255, blue: 22/255) }
        if value <= 160 { return Color.yellow }
        if value <= 300 { return Color.orange }
        return Color.red.opacity(0.75)
    }
}

struct DetailInfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(Color.ngMuted)
            Spacer()
            Text(value)
                .foregroundStyle(Color.ngText)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
        }
        .font(.subheadline.weight(.semibold))
    }
}

