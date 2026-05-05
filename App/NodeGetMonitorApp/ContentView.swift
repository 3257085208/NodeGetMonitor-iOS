import SwiftUI
import Foundation

private enum MainTab: Hashable {
    case monitor
    case assets
    case control
    case settings
}

struct ContentView: View {
    @State private var selectedTab: MainTab = .monitor

    var body: some View {
        TabView(selection: $selectedTab) {
            MonitorRootView(openSettings: { selectedTab = .settings })
                .tabItem { Label("监控", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(MainTab.monitor)

            BillingOverviewView()
                .tabItem { Label("资产", systemImage: "creditcard") }
                .tag(MainTab.assets)

            ControlCenterView()
                .tabItem { Label("主控", systemImage: "server.rack") }
                .tag(MainTab.control)

            SettingsView()
                .tabItem { Label("设置", systemImage: "gearshape") }
                .tag(MainTab.settings)
        }
        .tint(Color.ngPrimary)
    }
}

struct MonitorRootView: View {
    @EnvironmentObject private var serverStore: ServerProfileStore
    let openSettings: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView()

                if serverStore.servers.isEmpty {
                    EmptyHomeView(openSettings: openSettings)
                } else {
                    MultiServerHomeDashboardView()
                        .environmentObject(serverStore)
                }
            }
            .navigationTitle("NodeGet")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct MultiServerHomeDashboardView: View {
    @EnvironmentObject private var serverStore: ServerProfileStore

    @State private var agentUUIDsByServer: [UUID: [String]] = [:]
    @State private var summariesByServer: [UUID: [AgentSummary]] = [:]
    @State private var staticInfoByServerAndUUID: [String: StaticAgentInfo] = [:]
    @State private var metaByServerAndUUID: [String: AgentMeta] = [:]
    @State private var messagesByServer: [UUID: String] = [:]
    @State private var lastRefresh: Date?
    @State private var isLoading = false
    @State private var isRefreshing = false
    @State private var searchText = ""

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                header

                if totalAgentCount == 0 && !isLoading {
                    emptyView
                } else {
                    ForEach(serverStore.servers) { server in
                        let summaries = filteredSummaries(for: server)
                        if !summaries.isEmpty {
                            serverSection(server: server, summaries: summaries)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 32)
        }
        .searchable(text: $searchText, prompt: "搜索节点 / 主控…")
        .task(id: serverStore.servers.map(\.id).description) {
            await refreshAll()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { break }
                await refreshAll(showLoading: false)
            }
        }
        .refreshable { await refreshAll() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                DashboardPill(title: "Agent", value: "\(totalAgentCount)")
                DashboardPill(title: "主控", value: "\(serverStore.servers.count)", active: false)
                Spacer()
                Button { Task { await refreshAll() } } label: {
                    if isLoading {
                        ProgressView().tint(Color.ngPrimary).frame(width: 42, height: 42)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Color.ngPrimary)
                            .frame(width: 42, height: 42)
                    }
                }
                .background(Circle().fill(Color.ngPrimarySoft))
            }

            Text(statusMessage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.ngMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(isLoading ? "正在读取 Agent…" : "暂无 Agent 数据")
                .font(.system(size: 24, weight: .black, design: .rounded))
                .foregroundStyle(Color.ngText)
            Text("首页会聚合显示全部主控下的 Agent。下拉或等待 1 秒会自动刷新。")
                .font(.subheadline)
                .foregroundStyle(Color.ngMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .ngSoftCard()
    }

    private func serverSection(server: ServerProfile, summaries: [AgentSummary]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(server.name)
                        .font(.headline.weight(.black))
                        .foregroundStyle(Color.ngText)
                    Text(server.baseURL.host ?? server.baseURL.absoluteString)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.ngMuted)
                }
                Spacer()
                Text("\(summaries.count)")
                    .font(.caption.weight(.black))
                    .foregroundStyle(Color.ngPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Color.ngPrimarySoft))
            }

            ForEach(summaries) { summary in
                NavigationLink {
                    AgentDetailView(
                        server: server,
                        uuid: summary.uuid,
                        summary: summary,
                        staticInfo: staticInfo(server: server, uuid: summary.uuid),
                        meta: meta(server: server, uuid: summary.uuid)
                    )
                } label: {
                    DashboardAgentCardView(
                        summary: summary,
                        staticInfo: staticInfo(server: server, uuid: summary.uuid),
                        meta: meta(server: server, uuid: summary.uuid)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var totalAgentCount: Int {
        summariesByServer.values.reduce(0) { $0 + $1.count }
    }

    private var statusMessage: String {
        let time = lastRefresh.map { NodeGetFormatters.clockTime($0) } ?? "--"
        let failures = messagesByServer.values.filter { $0.contains("失败") }
        if failures.isEmpty {
            return "已连接 \(serverStore.servers.count) 个主控，读取到 \(totalAgentCount) 个 Agent。每 1 秒自动刷新于 \(time)。"
        }
        return "读取到 \(totalAgentCount) 个 Agent；部分主控失败：\(failures.prefix(2).joined(separator: "；"))"
    }

    private func cacheKey(server: ServerProfile, uuid: String) -> String {
        "\(server.id.uuidString)|\(uuid)"
    }

    private func staticInfo(server: ServerProfile, uuid: String) -> StaticAgentInfo? {
        staticInfoByServerAndUUID[cacheKey(server: server, uuid: uuid)]
    }

    private func meta(server: ServerProfile, uuid: String) -> AgentMeta? {
        metaByServerAndUUID[cacheKey(server: server, uuid: uuid)]
    }

    private func displayName(server: ServerProfile, uuid: String) -> String {
        meta(server: server, uuid: uuid)?.name.nilIfEmpty ?? staticInfo(server: server, uuid: uuid)?.displayName ?? uuid
    }

    private func filteredSummaries(for server: ServerProfile) -> [AgentSummary] {
        let sorted = summariesByServer[server.id, default: []].sorted { left, right in
            displayName(server: server, uuid: left.uuid).localizedCaseInsensitiveCompare(displayName(server: server, uuid: right.uuid)) == .orderedAscending
        }
        let keyword = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return sorted }
        return sorted.filter { summary in
            let info = staticInfo(server: server, uuid: summary.uuid)
            let meta = meta(server: server, uuid: summary.uuid)
            let candidates = [summary.uuid, server.name, server.baseURL.absoluteString, displayName(server: server, uuid: summary.uuid), meta?.region ?? "", info?.systemLine ?? "", info?.cpuLine ?? ""]
            return candidates.joined(separator: " ").localizedCaseInsensitiveContains(keyword)
        }
    }

    private func refreshAll(showLoading: Bool = true) async {
        guard !isRefreshing else { return }
        isRefreshing = true
        if showLoading { isLoading = true }
        defer {
            isRefreshing = false
            if showLoading { isLoading = false }
        }

        for server in serverStore.servers {
            await refresh(server: server)
        }
        lastRefresh = Date()
    }

    private func refresh(server: ServerProfile) async {
        guard let token = KeychainStore.shared.token(for: server.id) else {
            messagesByServer[server.id] = "\(server.name) 失败：未找到 Token"
            return
        }
        let client = NodeGetClient(baseURL: server.baseURL)
        do {
            let uuids = try await client.listAllAgentUUIDs(token: token).sorted()
            agentUUIDsByServer[server.id] = uuids
            let latest = try await client.latestDynamicSummaries(token: token, uuids: uuids)
            LocalTrendStore.shared.append(contentsOf: latest)
            summariesByServer[server.id] = latest

            if staticInfoByServerAndUUID.keys.filter({ $0.hasPrefix(server.id.uuidString) }).isEmpty {
                if let map = try? await client.latestStaticInfoMap(token: token, uuids: uuids) {
                    for (uuid, info) in map { staticInfoByServerAndUUID[cacheKey(server: server, uuid: uuid)] = info }
                }
            }

            if let metas = try? await client.metadataMap(token: token, uuids: uuids) {
                for (uuid, meta) in metas { metaByServerAndUUID[cacheKey(server: server, uuid: uuid)] = meta }
            }
            messagesByServer[server.id] = "\(server.name) OK"
        } catch {
            messagesByServer[server.id] = "\(server.name) 失败：\(error.localizedDescription)"
        }
    }
}

struct EmptyHomeView: View {
    let openSettings: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("还没有配置主控")
                        .font(.title2.bold())
                    Text("切到下方“设置”页，添加 NodeGet Server 地址和 Token。配置完成后，监控页会直接显示 Agent 列表。")
                        .font(.subheadline)
                        .foregroundStyle(Color.ngMuted)
                        .fixedSize(horizontal: false, vertical: true)

                    Button { openSettings() } label: {
                        Label("打开设置", systemImage: "gearshape.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(RoundedRectangle(cornerRadius: 18).fill(Color.ngPrimary))
                            .foregroundStyle(.white)
                    }
                    .padding(.top, 8)
                }
                .padding(20)
                .ngSoftCard()
            }
            .padding(20)
        }
    }
}

enum BillingCurrency: String, CaseIterable, Identifiable {
    case usd = "USD"
    case eur = "EUR"
    case gbp = "GBP"
    case cny = "CNY"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .usd: return "USD ($)"
        case .eur: return "EUR (€)"
        case .gbp: return "GBP (£)"
        case .cny: return "CNY (¥)"
        }
    }

    var symbol: String {
        switch self {
        case .usd: return "$"
        case .eur: return "€"
        case .gbp: return "£"
        case .cny: return "¥"
        }
    }
}

enum BillingSortKey: String, CaseIterable, Identifiable {
    case remainingDays = "剩余天数"
    case monthlyCost = "折算月成本"
    var id: String { rawValue }
}

struct BillingOverviewView: View {
    @EnvironmentObject private var serverStore: ServerProfileStore

    @State private var items: [BillingOverviewItem] = []
    @State private var message = "正在读取资产信息…"
    @State private var isLoading = false
    @State private var selectedCurrency: BillingCurrency = .usd
    @State private var sortKey: BillingSortKey = .remainingDays
    @State private var ascending = true
    @State private var exchangeRates: [BillingCurrency: Double] = [.usd: 1, .eur: 0.92, .gbp: 0.79, .cny: 7.20]
    @State private var exchangeUpdatedAt: Date?

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView()
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        header
                        controls
                        summaryGrid
                        sortControls
                        assetRows
                    }
                    .padding(20)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("资产")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { Task { await load() } } label: {
                        if isLoading { ProgressView() } else { Image(systemName: "arrow.clockwise") }
                    }
                }
            }
            .task {
                await refreshRates()
                await load()
            }
            .refreshable {
                await refreshRates()
                await load()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("资产")
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(Color.ngText)
            Text(message)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.ngMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Text("基准币种")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.ngMuted)

                Picker("基准币种", selection: $selectedCurrency) {
                    ForEach(BillingCurrency.allCases) { currency in
                        Text(currency.title).tag(currency)
                    }
                }
                .pickerStyle(.menu)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.white))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.ngBorder, lineWidth: 1))

                Button("刷新汇率") { Task { await refreshRates() } }
                    .font(.caption.weight(.bold))
                    .buttonStyle(.bordered)

                Spacer(minLength: 0)
            }

            Text(rateDescription)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.ngMuted)
                .lineLimit(2)
        }
    }

    private var summaryGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            BillingSummaryCard(icon: "creditcard", title: "折算月成本", value: currencyText(totalMonthlyCost), tint: .blue)
            BillingSummaryCard(icon: "chart.line.uptrend.xyaxis", title: "平均每台 / 月", value: currencyText(averageMonthlyCost), tint: .purple)
            BillingSummaryCard(icon: "chart.line.uptrend.xyaxis.circle", title: "折算剩余价值", value: currencyText(totalRemainingValue), tint: Color.ngPrimary)
            BillingSummaryCard(icon: "exclamationmark.triangle", title: "30 天内到期", value: "\(expiringSoonCount) 台", tint: .orange)
        }
    }

    private var sortControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("排序")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.ngMuted)
            HStack(spacing: 10) {
                sortButton(.remainingDays)
                sortButton(.monthlyCost)
                Spacer()
            }
        }
    }

    private func sortButton(_ key: BillingSortKey) -> some View {
        Button {
            if sortKey == key { ascending.toggle() } else { sortKey = key; ascending = true }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: sortKey == key ? (ascending ? "arrow.up" : "arrow.down") : "arrow.up.arrow.down")
                Text(key.rawValue)
            }
            .font(.caption.weight(.black))
            .foregroundStyle(sortKey == key ? Color.ngText : Color.ngMuted)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Capsule().fill(sortKey == key ? Color.white : Color.ngBackground.opacity(0.75)))
            .overlay(Capsule().stroke(Color.ngBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var assetRows: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionCaption(text: "机器")
            if isLoading && items.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(30)
                    .ngSoftCard()
            } else if sortedItems.isEmpty {
                Text("暂无资产数据。请确认 Token 拥有读取 metadata_* 的 KV 权限。")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.ngMuted)
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .ngSoftCard()
            } else {
                ForEach(sortedItems) { item in
                    AssetItemCard(item: item, currency: selectedCurrency, rates: exchangeRates)
                }
            }
        }
    }

    private var sortedItems: [BillingOverviewItem] {
        items.sorted { left, right in
            let result: Bool
            switch sortKey {
            case .remainingDays:
                let l = left.meta?.remainingDays ?? Int.max
                let r = right.meta?.remainingDays ?? Int.max
                if l == r { result = left.displayName.localizedCaseInsensitiveCompare(right.displayName) == .orderedAscending } else { result = l < r }
            case .monthlyCost:
                let l = convertedMonthlyCost(left)
                let r = convertedMonthlyCost(right)
                if abs(l - r) < 0.0001 { result = left.displayName.localizedCaseInsensitiveCompare(right.displayName) == .orderedAscending } else { result = l < r }
            }
            return ascending ? result : !result
        }
    }

    private var totalMonthlyCost: Double { items.reduce(0) { $0 + convertedMonthlyCost($1) } }
    private var averageMonthlyCost: Double { items.isEmpty ? 0 : totalMonthlyCost / Double(items.count) }
    private var totalRemainingValue: Double { items.reduce(0) { $0 + convertedRemainingValue($1) } }
    private var expiringSoonCount: Int { items.filter { item in guard let days = item.meta?.remainingDays else { return false }; return days >= 0 && days <= 30 }.count }

    private var rateDescription: String {
        let source = exchangeUpdatedAt.map { NodeGetFormatters.dateTime($0) } ?? "内置备用汇率"
        return "汇率基准：USD，更新于 \(source)。费用字段来自 NodeGet Agent metadata。"
    }

    private func convertedMonthlyCost(_ item: BillingOverviewItem) -> Double {
        guard let meta = item.meta, meta.price > 0, meta.priceCycle > 0 else { return 0 }
        return convert(meta.price / Double(meta.priceCycle) * 30, from: currency(from: meta.priceUnit), to: selectedCurrency)
    }

    private func convertedRemainingValue(_ item: BillingOverviewItem) -> Double {
        guard let meta = item.meta, meta.price > 0, meta.priceCycle > 0, let days = meta.remainingDays, days > 0 else { return 0 }
        return convert(meta.price / Double(meta.priceCycle) * Double(days), from: currency(from: meta.priceUnit), to: selectedCurrency)
    }

    private func currencyText(_ value: Double) -> String { "\(selectedCurrency.symbol)\(String(format: "%.2f", value))" }

    private func convert(_ amount: Double, from source: BillingCurrency, to target: BillingCurrency) -> Double {
        let sourceRate = exchangeRates[source] ?? 1
        let targetRate = exchangeRates[target] ?? 1
        guard sourceRate > 0 else { return amount }
        return amount / sourceRate * targetRate
    }

    private func currency(from unit: String) -> BillingCurrency {
        let clean = unit.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if ["USD", "$", "US$"].contains(clean) { return .usd }
        if ["EUR", "€"].contains(clean) { return .eur }
        if ["GBP", "£"].contains(clean) { return .gbp }
        if ["CNY", "RMB", "CN¥", "¥", "￥"].contains(clean) { return .cny }
        return .usd
    }

    private func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        var output: [BillingOverviewItem] = []
        var errors: [String] = []

        for server in serverStore.servers {
            guard let token = KeychainStore.shared.token(for: server.id) else { errors.append("\(server.name)：缺少 Token"); continue }
            let client = NodeGetClient(baseURL: server.baseURL)
            do {
                let uuids = try await client.listAllAgentUUIDs(token: token).sorted()
                let meta = try await client.metadataMap(token: token, uuids: uuids)
                let staticMap = (try? await client.latestStaticInfoMap(token: token, uuids: uuids)) ?? [:]
                for uuid in uuids { output.append(BillingOverviewItem(server: server, uuid: uuid, meta: meta[uuid], staticInfo: staticMap[uuid])) }
            } catch {
                errors.append("\(server.name)：\(error.localizedDescription)")
            }
        }
        items = output
        message = errors.isEmpty ? "读取到 \(items.count) 台机器的资产信息。" : "读取到 \(items.count) 台机器；部分失败：\(errors.prefix(2).joined(separator: "；"))"
    }

    private func refreshRates() async {
        guard let url = URL(string: "https://api.frankfurter.app/latest?from=USD&to=EUR,GBP,CNY") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(FrankfurterResponse.self, from: data)
            var rates: [BillingCurrency: Double] = [.usd: 1]
            rates[.eur] = decoded.rates["EUR"] ?? exchangeRates[.eur]
            rates[.gbp] = decoded.rates["GBP"] ?? exchangeRates[.gbp]
            rates[.cny] = decoded.rates["CNY"] ?? exchangeRates[.cny]
            exchangeRates = rates
            exchangeUpdatedAt = Date()
        } catch {
            // 保留内置备用汇率。
        }
    }
}

struct FrankfurterResponse: Decodable { let rates: [String: Double] }

struct BillingOverviewItem: Identifiable {
    let server: ServerProfile
    let uuid: String
    let meta: AgentMeta?
    let staticInfo: StaticAgentInfo?
    var id: String { "\(server.id.uuidString)-\(uuid)" }
    var displayName: String { meta?.name.nilIfEmpty ?? staticInfo?.displayName ?? uuid }
}

struct BillingSummaryCard: View {
    let icon: String
    let title: String
    let value: String
    let tint: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3.weight(.bold))
                .foregroundStyle(tint)
                .frame(width: 38, height: 38)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(tint.opacity(0.13)))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.caption.weight(.bold)).foregroundStyle(Color.ngMuted)
                Text(value).font(.title3.weight(.black)).foregroundStyle(Color.ngText).monospacedDigit().minimumScaleFactor(0.7).lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .ngSoftCard()
    }
}

struct AssetItemCard: View {
    let item: BillingOverviewItem
    let currency: BillingCurrency
    let rates: [BillingCurrency: Double]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(item.displayName).font(.title3.weight(.black)).foregroundStyle(Color.ngText)
                    Text("\(String(item.uuid.suffix(8))) · \(item.server.name)").font(.caption.weight(.semibold)).foregroundStyle(Color.ngMuted).lineLimit(1)
                }
                Spacer()
                remainBadge
            }
            Divider()
            HStack(spacing: 14) {
                AssetMetric(title: "价格 / 周期", value: "\(convertedText(price)) / \(cycleDays)天", subvalue: "≈ \(convertedText(monthlyCost)) / 30天")
                AssetMetric(title: "到期时间", value: NodeGetFormatters.date(item.meta?.expiryDate), subvalue: item.meta?.remainingDays.map { "剩余 \($0) 天" } ?? "--")
            }
            HStack(spacing: 14) {
                AssetMetric(title: "剩余价值", value: convertedText(remainingValue), subvalue: item.meta?.displayPrice ?? "原始价格 --")
                VStack(alignment: .leading, spacing: 8) {
                    Text("剩余时间占比").font(.caption.weight(.bold)).foregroundStyle(Color.ngMuted)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4).fill(Color.ngBorder)
                            RoundedRectangle(cornerRadius: 4).fill(progressColor).frame(width: geo.size.width * progress)
                        }
                    }
                    .frame(height: 8)
                    Text(item.meta?.remainingDays.map { "剩余 \($0) 天" } ?? "--").font(.caption2.weight(.semibold)).foregroundStyle(Color.ngMuted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(18)
        .ngSoftCard()
    }

    private var price: Double { guard let meta = item.meta else { return 0 }; return convert(meta.price, from: sourceCurrency) }
    private var monthlyCost: Double { guard let meta = item.meta, meta.priceCycle > 0 else { return 0 }; return convert(meta.price / Double(meta.priceCycle) * 30, from: sourceCurrency) }
    private var remainingValue: Double { guard let meta = item.meta, meta.priceCycle > 0, let days = meta.remainingDays, days > 0 else { return 0 }; return convert(meta.price / Double(meta.priceCycle) * Double(days), from: sourceCurrency) }
    private var cycleDays: Int { max(item.meta?.priceCycle ?? 0, 0) }

    private var sourceCurrency: BillingCurrency {
        let clean = (item.meta?.priceUnit ?? "USD").trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if ["USD", "$", "US$"].contains(clean) { return .usd }
        if ["EUR", "€"].contains(clean) { return .eur }
        if ["GBP", "£"].contains(clean) { return .gbp }
        if ["CNY", "RMB", "CN¥", "¥", "￥"].contains(clean) { return .cny }
        return .usd
    }

    private var progress: CGFloat {
        guard let remaining = item.meta?.remainingDays, let cycle = item.meta?.priceCycle, cycle > 0 else { return 0 }
        return CGFloat(min(max(Double(remaining) / Double(cycle), 0), 1))
    }

    private var progressColor: Color {
        let days = item.meta?.remainingDays ?? 9999
        if days <= 7 { return .red }
        if days <= 30 { return .orange }
        return Color.ngPrimary
    }

    private var remainBadge: some View {
        let days = item.meta?.remainingDays
        let color: Color = (days ?? 9999) <= 7 ? .red : ((days ?? 9999) <= 30 ? .orange : Color.ngPrimary)
        return Text(days.map { "\($0) 天" } ?? "--")
            .font(.caption.weight(.black))
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(color.opacity(0.13)))
    }

    private func convert(_ amount: Double, from source: BillingCurrency) -> Double {
        let sourceRate = rates[source] ?? 1
        let targetRate = rates[currency] ?? 1
        guard sourceRate > 0 else { return amount }
        return amount / sourceRate * targetRate
    }

    private func convertedText(_ value: Double) -> String { "\(currency.symbol)\(String(format: "%.2f", value))" }
}

struct AssetMetric: View {
    let title: String
    let value: String
    let subvalue: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.caption.weight(.bold)).foregroundStyle(Color.ngMuted)
            Text(value).font(.headline.weight(.black)).foregroundStyle(Color.ngText).lineLimit(1).minimumScaleFactor(0.68)
            Text(subvalue).font(.caption2.weight(.semibold)).foregroundStyle(Color.ngMuted).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SettingsView: View {
    @EnvironmentObject private var serverStore: ServerProfileStore
    @Environment(\.openURL) private var openURL

    private let githubURL = URL(string: "https://github.com/3257085208/NodeGetMonitor-iOS")!

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        Text("设置")
                            .font(.system(size: 34, weight: .black, design: .rounded))
                            .foregroundStyle(Color.ngText)

                        masterSection
                        projectSection
                        privacySection
                    }
                    .padding(20)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var masterSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionCaption(text: "主控")

            NavigationLink {
                AddServerView().environmentObject(serverStore)
            } label: {
                HomeActionCard(icon: "plus.circle.fill", title: "添加主控", subtitle: "配置 NodeGet Server 地址与 Token")
            }
            .buttonStyle(.plain)

            if serverStore.servers.isEmpty {
                Text("暂无主控。添加后，监控页会直接聚合显示全部 Agent。")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.ngMuted)
                    .padding(18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .ngSoftCard()
            } else {
                VStack(spacing: 12) {
                    ForEach(serverStore.servers) { server in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(server.name)
                                    .font(.headline.weight(.black))
                                    .foregroundStyle(Color.ngText)
                                Text(server.baseURL.absoluteString)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Color.ngMuted)
                                    .lineLimit(1)
                            }
                            Spacer()
                            Button(role: .destructive) {
                                serverStore.delete(server)
                            } label: {
                                Image(systemName: "trash")
                                    .font(.headline)
                            }
                        }
                        .padding(18)
                        .ngSoftCard()
                    }
                }
            }
        }
    }

    private var projectSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionCaption(text: "项目")
            VStack(spacing: 14) {
                DetailInfoRow(title: "App", value: "NodeGet Monitor")
                DetailInfoRow(title: "版本", value: "0.6.1")
                DetailInfoRow(title: "刷新", value: "监控与详情页每 1 秒自动刷新")
                Button {
                    openURL(githubURL)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("GitHub 开源地址")
                                .font(.headline.weight(.black))
                                .foregroundStyle(Color.ngText)
                            Text(githubURL.absoluteString)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.ngMuted)
                                .lineLimit(1)
                        }
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(Color.ngPrimary)
                    }
                }
                .buttonStyle(.plain)
            }
            .padding(18)
            .ngSoftCard()
        }
    }

    private var privacySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionCaption(text: "隐私")
            VStack(alignment: .leading, spacing: 10) {
                Label("Token 保存到本机 iOS Keychain", systemImage: "key.fill")
                    .font(.headline.weight(.black))
                    .foregroundStyle(Color.ngText)
                Text("App 不会把你的主控地址、Token、Agent UUID 或监控数据上传到第三方服务器。资产页的币种换算会从公开汇率接口读取汇率；失败时使用内置备用汇率。")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.ngMuted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)
            .ngSoftCard()
        }
    }
}

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView()
                VStack(alignment: .leading, spacing: 16) {
                    Text("NodeGet")
                        .font(.system(size: 38, weight: .black, design: .rounded))
                    Text("iPhone 原生监控仪表盘。")
                        .font(.headline)
                        .foregroundStyle(Color.ngMuted)
                    VStack(spacing: 12) {
                        DetailInfoRow(title: "版本", value: "0.6.1")
                        DetailInfoRow(title: "刷新", value: "首页与详情页每 1 秒自动刷新")
                        DetailInfoRow(title: "构建", value: "Unsigned IPA 文件名会带版本号")
                    }
                    .padding(18)
                    .ngSoftCard()
                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("关于")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() } } }
        }
    }
}

struct PrivacyView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ZStack {
                AppBackgroundView()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("隐私")
                            .font(.system(size: 38, weight: .black, design: .rounded))
                        Text("Token 保存在本机 iOS Keychain。App 不会把你的主控地址、Token、Agent UUID 或监控数据上传到第三方服务器。")
                            .font(.headline)
                            .foregroundStyle(Color.ngMuted)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(18)
                            .ngSoftCard()
                    }
                    .padding(20)
                }
            }
            .navigationTitle("隐私")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完成") { dismiss() } } }
        }
    }
}

struct HomeActionCard: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(.blue)
                .frame(width: 44, height: 44)
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.title3.bold()).foregroundStyle(Color.black)
                Text(subtitle).font(.subheadline).foregroundStyle(Color.ngMuted).fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.headline).foregroundStyle(Color.ngMuted.opacity(0.8))
        }
        .padding(18)
        .ngSoftCard()
    }
}
