//
//  ParentDashboardView.swift
//  pinghu12250
//
//  家长查看孩子仪表盘（只读，与学生界面一致）
//

import SwiftUI
import Charts

struct ParentDashboardView: View {
    let childId: String

    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedRange: DashboardTimeRange = .month
    @State private var animate = false

    // 数据状态
    @State private var todayStatus: [String: CheckInStatus] = [:]
    @State private var userInfo: UserInfo?
    @State private var summary: FullSummary?
    @State private var byTemplate: [String: TemplateStats] = [:]
    @State private var byRequirement: RequirementStats?
    @State private var byRuleType: [String: RuleTypeStats] = [:]
    @State private var timeStats: TimeStats?
    @State private var trend: [TrendItem] = []
    @State private var heatmap: [HeatmapItem] = []

    @Environment(\.viewingChild) var child

    private var timezoneOffset: Int {
        -(TimeZone.current.secondsFromGMT() / 60)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 只读提示
                if let child = child {
                    ParentModeBanner(childName: child.displayName)
                }

                // 今日打卡状态
                TodayCheckInSection(
                    items: CheckInItem.allItems,
                    getStatus: getStatus,
                    animate: animate
                )

                // 时间范围选择器
                TimeRangeSelector(
                    selected: $selectedRange,
                    onChange: { _ in loadData() }
                )

                if isLoading {
                    LoadingView()
                } else if let error = errorMessage {
                    ErrorView(message: error) {
                        loadData()
                    }
                } else {
                    // 成长徽章区
                    GrowthBadgesSection(
                        approvalStreak: userInfo?.approvalStreak ?? 0,
                        joinedDays: userInfo?.joinedDays ?? 0,
                        animate: animate
                    )

                    // 总体概览
                    if let summary = summary {
                        OverviewSection(
                            summary: summary,
                            pieData: getStatusPieData(),
                            animate: animate
                        )
                    }

                    // 趋势图
                    if !trend.isEmpty {
                        TrendChartSection(
                            trend: trend,
                            animate: animate
                        )
                    }

                    // 时间维度统计
                    if let timeStats = timeStats {
                        TimeStatsSection(
                            stats: timeStats,
                            animate: animate
                        )
                    }

                    // 热力图
                    if !heatmap.isEmpty {
                        HeatmapSection(
                            data: heatmap,
                            animate: animate
                        )
                    }

                    // 类型分析
                    TypeAnalysisSection(
                        requirementData: getRequirementChartData(),
                        ruleTypeData: getRuleTypeChartData(),
                        animate: animate
                    )

                    // 积分统计
                    if let summary = summary, summary.totalPoints > 0 {
                        PointsSection(
                            totalPoints: summary.totalPoints,
                            timeStats: timeStats,
                            byTemplate: byTemplate,
                            animate: animate
                        )
                    }

                    // 各项目详情（只读，不可跳转）
                    if !byTemplate.isEmpty {
                        ParentTemplateDetailsSection(
                            templates: getTopTemplates(),
                            animate: animate
                        )
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .refreshable {
            await loadDataAsync()
        }
        .task {
            await loadDataAsync()
            try? await Task.sleep(nanoseconds: 100_000_000)
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                animate = true
            }
        }
        .onChange(of: selectedRange) { _, _ in
            loadData()
        }
    }

    // MARK: - 数据加载

    private func loadData() {
        Task {
            await loadDataAsync()
        }
    }

    private func loadDataAsync() async {
        isLoading = true
        errorMessage = nil

        // 并行加载今日状态和全量统计
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await loadTodayStatus() }
            group.addTask { await loadFullStats() }
        }

        isLoading = false
    }

    private func loadTodayStatus() async {
        do {
            let templateNames = CheckInItem.templateNames
                .addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
            let endpoint = "/submissions/child/\(childId)/today-status?templateNames=\(templateNames)&timezoneOffset=\(timezoneOffset)"

            let response: TodayStatusResponse = try await APIService.shared.get(endpoint)

            var statusMap: [String: CheckInStatus] = [:]
            for item in CheckInItem.allItems {
                if let statusItem = response.todayStatus[item.templateName] {
                    if let unwrapped = statusItem {
                        statusMap[item.id] = CheckInStatus(from: unwrapped.status)
                    } else {
                        statusMap[item.id] = .notSubmitted
                    }
                } else {
                    statusMap[item.id] = .notSubmitted
                }
            }

            await MainActor.run {
                todayStatus = statusMap
            }
        } catch {
            #if DEBUG
            print("📅 加载今日状态失败: \(error)")
            #endif
        }
    }

    private func loadFullStats() async {
        do {
            let endpoint = "/submissions/child/\(childId)/full-stats?range=\(selectedRange.rawValue)&timezoneOffset=\(timezoneOffset)"

            let response: FullDashboardResponse = try await APIService.shared.get(endpoint)

            await MainActor.run {
                userInfo = response.userInfo
                summary = response.summary
                byTemplate = response.byTemplate
                byRequirement = response.byRequirement
                byRuleType = response.byRuleType
                timeStats = response.timeStats
                trend = response.trend
                heatmap = response.heatmap
            }
        } catch {
            await MainActor.run {
                errorMessage = "加载统计数据失败"
            }
            #if DEBUG
            print("📊 加载失败: \(error)")
            #endif
        }
    }

    // MARK: - 辅助方法

    func getStatus(for item: CheckInItem) -> CheckInStatus {
        todayStatus[item.id] ?? .notSubmitted
    }

    func getStatusPieData() -> [PieSlice] {
        guard let summary = summary, summary.total > 0 else { return [] }

        let total = Double(summary.approved + summary.pending + summary.rejected)
        guard total > 0 else { return [] }

        var slices: [PieSlice] = []

        if summary.approved > 0 {
            slices.append(PieSlice(
                label: "已通过",
                value: Double(summary.approved),
                color: .green,
                percentage: Double(summary.approved) / total * 100
            ))
        }

        if summary.pending > 0 {
            slices.append(PieSlice(
                label: "待审核",
                value: Double(summary.pending),
                color: .orange,
                percentage: Double(summary.pending) / total * 100
            ))
        }

        if summary.rejected > 0 {
            slices.append(PieSlice(
                label: "已退回",
                value: Double(summary.rejected),
                color: .red,
                percentage: Double(summary.rejected) / total * 100
            ))
        }

        return slices
    }

    func getRequirementChartData() -> [ChartDataPoint] {
        guard let req = byRequirement else { return [] }

        var data: [ChartDataPoint] = []

        if req.text.total > 0 {
            data.append(ChartDataPoint(label: "文本", value: Double(req.text.total), color: .blue))
        }
        if req.image.total > 0 {
            data.append(ChartDataPoint(label: "图片", value: Double(req.image.total), color: .purple))
        }
        if req.audio.total > 0 {
            data.append(ChartDataPoint(label: "录音", value: Double(req.audio.total), color: .pink))
        }
        if req.link.total > 0 {
            data.append(ChartDataPoint(label: "链接", value: Double(req.link.total), color: .cyan))
        }

        return data
    }

    func getRuleTypeChartData() -> [ChartDataPoint] {
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .cyan, .red, .yellow]

        return byRuleType.enumerated().map { index, item in
            ChartDataPoint(
                label: item.key,
                value: Double(item.value.total),
                color: colors[index % colors.count]
            )
        }
    }

    func getTopTemplates(limit: Int = 10) -> [(name: String, stats: TemplateStats)] {
        byTemplate
            .sorted { $0.value.total > $1.value.total }
            .prefix(limit)
            .map { ($0.key, $0.value) }
    }
}

// MARK: - 家长版项目详情（只读，无跳转）

struct ParentTemplateDetailsSection: View {
    let templates: [(name: String, stats: TemplateStats)]
    let animate: Bool

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "list.bullet.rectangle")
                        .foregroundColor(.appPrimary)
                    Text("各项目详情")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                }
            }

            if isExpanded {
                ForEach(Array(templates.enumerated()), id: \.offset) { _, item in
                    ParentTemplateRow(name: item.name, stats: item.stats)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        .opacity(animate ? 1 : 0)
        .animation(.easeInOut(duration: 0.5).delay(0.6), value: animate)
    }
}

struct ParentTemplateRow: View {
    let name: String
    let stats: TemplateStats

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Label("\(stats.total)", systemImage: "doc.text")
                    Label("\(stats.approved)", systemImage: "checkmark.circle")
                        .foregroundColor(.green)
                    if let points = stats.points, points > 0 {
                        Label("+\(points)", systemImage: "star.fill")
                            .foregroundColor(.yellow)
                    }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

#Preview {
    ParentDashboardView(childId: "test-child-id")
}
