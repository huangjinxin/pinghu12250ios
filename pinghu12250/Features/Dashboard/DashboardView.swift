//
//  DashboardView.swift
//  pinghu12250
//
//  仪表盘主视图 - 全量统计

import SwiftUI
import Charts

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @State private var animate = false
    @State private var showChallengeDetail = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // 每日挑战入口
                DailyChallengeSection(
                    viewModel: viewModel,
                    animate: animate
                ) {
                    showChallengeDetail = true
                }

                // 今日打卡状态（三项）
                TodayCheckInSection(
                    items: CheckInItem.allItems,
                    getStatus: viewModel.getStatus,
                    animate: animate
                )

                // 时间范围选择器
                TimeRangeSelector(
                    selected: $viewModel.selectedRange,
                    onChange: viewModel.changeRange
                )

                if viewModel.isLoading {
                    LoadingView()
                } else if let error = viewModel.errorMessage {
                    ErrorView(message: error) {
                        Task { await viewModel.loadData() }
                    }
                } else {
                    // 成长徽章区
                    GrowthBadgesSection(
                        approvalStreak: viewModel.approvalStreak,
                        joinedDays: viewModel.joinedDays,
                        animate: animate
                    )

                    // 总体概览
                    if let summary = viewModel.summary {
                        OverviewSection(
                            summary: summary,
                            pieData: viewModel.getStatusPieData(),
                            animate: animate
                        )
                    }

                    // 趋势图
                    if !viewModel.trend.isEmpty {
                        TrendChartSection(
                            trend: viewModel.trend,
                            animate: animate
                        )
                    }

                    // 时间维度统计
                    if let timeStats = viewModel.timeStats {
                        TimeStatsSection(
                            stats: timeStats,
                            animate: animate
                        )
                    }

                    // 热力图
                    if !viewModel.heatmap.isEmpty {
                        HeatmapSection(
                            data: viewModel.heatmap,
                            animate: animate
                        )
                    }

                    // 类型分析
                    TypeAnalysisSection(
                        requirementData: viewModel.getRequirementChartData(),
                        ruleTypeData: viewModel.getRuleTypeChartData(),
                        animate: animate
                    )

                    // 积分统计
                    if let summary = viewModel.summary, summary.totalPoints > 0 {
                        PointsSection(
                            totalPoints: summary.totalPoints,
                            timeStats: viewModel.timeStats,
                            byTemplate: viewModel.byTemplate,
                            animate: animate
                        )
                    }

                    // 各项目详情
                    if !viewModel.byTemplate.isEmpty {
                        TemplateDetailsSection(
                            templates: viewModel.getTopTemplates(),
                            onTap: viewModel.navigateToMySubmissions,
                            animate: animate
                        )
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .refreshable {
            await viewModel.loadData()
        }
        .task {
            await viewModel.loadData()
            try? await Task.sleep(nanoseconds: 100_000_000)
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                animate = true
            }
        }
        .sheet(isPresented: $showChallengeDetail) {
            DailyChallengeDetailView(viewModel: viewModel)
        }
    }
}

// MARK: - 每日挑战入口

struct DailyChallengeSection: View {
    @ObservedObject var viewModel: DashboardViewModel
    let animate: Bool
    let onTap: () -> Void

    @State private var pulseScale: CGFloat = 1.0

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // 左侧图标和进度
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 4)
                        .frame(width: 56, height: 56)

                    Circle()
                        .trim(from: 0, to: CGFloat(viewModel.completedCount) / 3.0)
                        .stroke(
                            LinearGradient(
                                colors: [.indigo, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .frame(width: 56, height: 56)
                        .rotationEffect(.degrees(-90))

                    Text("🎯")
                        .font(.title2)
                }

                // 中间内容
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("每日挑战")
                            .font(.headline)
                            .foregroundColor(.primary)

                        if let status = viewModel.rewardStatus, status.canClaim {
                            Text("可领取")
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange)
                                .cornerRadius(4)
                                .scaleEffect(pulseScale)
                                .onAppear {
                                    withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                                        pulseScale = 1.1
                                    }
                                }
                        }
                    }

                    HStack(spacing: 12) {
                        Label("\(viewModel.completedCount)/3 完成", systemImage: "checkmark.circle")
                            .foregroundColor(viewModel.completedCount == 3 ? .green : .secondary)

                        if viewModel.approvalStreak > 0 {
                            Label("\(viewModel.approvalStreak)天连续", systemImage: "flame.fill")
                                .foregroundColor(.orange)
                        }
                    }
                    .font(.caption)
                }

                Spacer()

                // 右侧箭头和奖励提示
                VStack(alignment: .trailing, spacing: 4) {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let status = viewModel.rewardStatus {
                        if status.claimed {
                            Text("已领取")
                                .font(.caption2)
                                .foregroundColor(.green)
                        } else if status.canClaim, let reward = status.estimatedReward {
                            Text("+\(reward.totalPoints)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.orange)
                        }
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        viewModel.rewardStatus?.canClaim == true
                            ? LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(colors: [Color.clear, Color.clear], startPoint: .topLeading, endPoint: .bottomTrailing),
                        lineWidth: 2
                    )
            )
            .shadow(
                color: viewModel.rewardStatus?.canClaim == true ? .orange.opacity(0.3) : .black.opacity(0.05),
                radius: viewModel.rewardStatus?.canClaim == true ? 8 : 4,
                x: 0,
                y: 2
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(animate ? 1 : 0.95)
        .opacity(animate ? 1 : 0)
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: animate)
    }
}

// MARK: - 时间范围选择器

struct TimeRangeSelector: View {
    @Binding var selected: DashboardTimeRange
    let onChange: (DashboardTimeRange) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(DashboardTimeRange.allCases) { range in
                    Button {
                        selected = range
                        onChange(range)
                    } label: {
                        Text(range.displayName)
                            .font(.subheadline)
                            .fontWeight(selected == range ? .semibold : .regular)
                            .foregroundColor(selected == range ? .white : .secondary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(selected == range ? Color.appPrimary : Color(.systemGray5))
                            )
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

// MARK: - 成长徽章区

struct GrowthBadgesSection: View {
    let approvalStreak: Int
    let joinedDays: Int
    let animate: Bool

    @State private var fireScale: CGFloat = 1.0

    var body: some View {
        HStack(spacing: 12) {
            // 连续打卡
            VStack(spacing: 8) {
                Text("🔥")
                    .font(.system(size: 36))
                    .scaleEffect(fireScale)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                            fireScale = 1.15
                        }
                    }

                VStack(spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(approvalStreak)")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.orange)
                        Text("天")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text("连续通过")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(LinearGradient(colors: [.orange.opacity(0.1), .red.opacity(0.05)], startPoint: .top, endPoint: .bottom))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.orange.opacity(0.3), lineWidth: 1)
            )

            // 已加入天数
            VStack(spacing: 8) {
                Text("📅")
                    .font(.system(size: 36))

                VStack(spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text("\(joinedDays)")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.blue)
                        Text("天")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Text("已加入")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(LinearGradient(colors: [.blue.opacity(0.1), .cyan.opacity(0.05)], startPoint: .top, endPoint: .bottom))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
            )
        }
        .scaleEffect(animate ? 1 : 0.9)
        .opacity(animate ? 1 : 0)
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: animate)
    }
}

// MARK: - 总体概览

struct OverviewSection: View {
    let summary: FullSummary
    let pieData: [PieSlice]
    let animate: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundColor(.appPrimary)
                Text("总体概览")
                    .font(.headline)
                Spacer()
            }

            // 数字卡片
            HStack(spacing: 8) {
                StatCard(title: "总提交", value: summary.total, color: .blue, icon: "doc.text.fill")
                StatCard(title: "通过率", value: summary.passRate, suffix: "%", color: .green, icon: "checkmark.seal.fill")
                StatCard(title: "待审核", value: summary.pending, color: .orange, icon: "clock.fill")
                StatCard(title: "获积分", value: summary.totalPoints, prefix: "+", color: .purple, icon: "star.fill")
            }

            // 状态分布条
            if summary.total > 0 {
                StatusBar(
                    approved: summary.approved,
                    pending: summary.pending,
                    rejected: summary.rejected,
                    total: summary.total
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        .scaleEffect(animate ? 1 : 0.95)
        .opacity(animate ? 1 : 0)
        .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.1), value: animate)
    }
}

struct StatCard: View {
    let title: String
    let value: Int
    var prefix: String = ""
    var suffix: String = ""
    let color: Color
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)

            HStack(alignment: .firstTextBaseline, spacing: 1) {
                if !prefix.isEmpty {
                    Text(prefix)
                        .font(.caption)
                        .foregroundColor(color)
                }
                Text("\(value)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                if !suffix.isEmpty {
                    Text(suffix)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(color.opacity(0.1))
        .cornerRadius(10)
    }
}

struct StatusBar: View {
    let approved: Int
    let pending: Int
    let rejected: Int
    let total: Int

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geo in
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.green)
                        .frame(width: geo.size.width * CGFloat(approved) / CGFloat(total))

                    Rectangle()
                        .fill(Color.orange)
                        .frame(width: geo.size.width * CGFloat(pending) / CGFloat(total))

                    Rectangle()
                        .fill(Color.red)
                        .frame(width: geo.size.width * CGFloat(rejected) / CGFloat(total))
                }
                .cornerRadius(4)
            }
            .frame(height: 8)

            HStack {
                Label("\(approved)通过", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Spacer()
                Label("\(pending)待审", systemImage: "clock.fill")
                    .foregroundColor(.orange)
                Spacer()
                Label("\(rejected)退回", systemImage: "xmark.circle.fill")
                    .foregroundColor(.red)
            }
            .font(.caption2)
        }
    }
}

// MARK: - 趋势图

struct TrendChartSection: View {
    let trend: [TrendItem]
    let animate: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.appPrimary)
                Text("近期趋势")
                    .font(.headline)
                Spacer()
            }

            Chart {
                ForEach(trend) { item in
                    LineMark(
                        x: .value("日期", item.shortDate),
                        y: .value("提交数", animate ? item.submitted : 0)
                    )
                    .foregroundStyle(Color.blue)
                    .symbol(.circle)
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("日期", item.shortDate),
                        y: .value("提交数", animate ? item.submitted : 0)
                    )
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.3), Color.blue.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }
            }
            .frame(height: 160)
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 7)) { _ in
                    AxisValueLabel()
                        .font(.caption2)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisValueLabel()
                        .font(.caption2)
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [4]))
                        .foregroundStyle(Color.gray.opacity(0.3))
                }
            }
            .animation(.easeInOut(duration: 1.0), value: animate)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

// MARK: - 时间维度统计

struct TimeStatsSection: View {
    let stats: TimeStats
    let animate: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(.appPrimary)
                Text("时间统计")
                    .font(.headline)
                Spacer()
            }

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 8) {
                TimeStatCard(title: "今日", submitted: stats.today.submitted, approved: stats.today.approved, points: stats.today.points, color: .blue)
                TimeStatCard(title: "本周", submitted: stats.thisWeek.submitted, approved: stats.thisWeek.approved, points: stats.thisWeek.points, color: .green)
                TimeStatCard(title: "本月", submitted: stats.thisMonth.submitted, approved: stats.thisMonth.approved, points: stats.thisMonth.points, color: .orange)
                TimeStatCard(title: "今年", submitted: stats.thisYear.submitted, approved: stats.thisYear.approved, points: stats.thisYear.points, color: .purple)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        .scaleEffect(animate ? 1 : 0.95)
        .opacity(animate ? 1 : 0)
        .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.2), value: animate)
    }
}

struct TimeStatCard: View {
    let title: String
    let submitted: Int
    let approved: Int
    let points: Int
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(color)

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(submitted)")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    Text("提交")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("+\(points)")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.green)
                    Text("积分")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - 热力图

struct HeatmapSection: View {
    let data: [HeatmapItem]
    let animate: Bool

    private let columns = Array(repeating: GridItem(.fixed(12), spacing: 2), count: 7)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "square.grid.3x3.fill")
                    .foregroundColor(.appPrimary)
                Text("活动热力图")
                    .font(.headline)
                Spacer()

                // 图例
                HStack(spacing: 4) {
                    Text("少")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    ForEach(0..<5) { level in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(heatmapColor(level: level))
                            .frame(width: 10, height: 10)
                    }
                    Text("多")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHGrid(rows: columns, spacing: 2) {
                    ForEach(data) { item in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(heatmapColor(level: item.level))
                            .frame(width: 12, height: 12)
                    }
                }
            }
            .frame(height: 100)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        .opacity(animate ? 1 : 0)
        .animation(.easeInOut(duration: 0.5).delay(0.3), value: animate)
    }

    private func heatmapColor(level: Int) -> Color {
        switch level {
        case 0: return Color(.systemGray5)
        case 1: return Color.green.opacity(0.3)
        case 2: return Color.green.opacity(0.5)
        case 3: return Color.green.opacity(0.7)
        default: return Color.green
        }
    }
}

// MARK: - 类型分析

struct TypeAnalysisSection: View {
    let requirementData: [ChartDataPoint]
    let ruleTypeData: [ChartDataPoint]
    let animate: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.pie.fill")
                    .foregroundColor(.appPrimary)
                Text("类型分析")
                    .font(.headline)
                Spacer()
            }

            HStack(spacing: 12) {
                // 提交类型
                if !requirementData.isEmpty {
                    TypeCard(title: "提交类型", data: requirementData)
                }

                // 技术类型
                if !ruleTypeData.isEmpty {
                    TypeCard(title: "技术类型", data: ruleTypeData)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        .opacity(animate ? 1 : 0)
        .animation(.easeInOut(duration: 0.5).delay(0.4), value: animate)
    }
}

struct TypeCard: View {
    let title: String
    let data: [ChartDataPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)

            ForEach(data) { item in
                HStack {
                    Circle()
                        .fill(item.color)
                        .frame(width: 8, height: 8)
                    Text(item.label)
                        .font(.caption)
                    Spacer()
                    Text("\(Int(item.value))")
                        .font(.caption)
                        .fontWeight(.medium)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

// MARK: - 积分统计

struct PointsSection: View {
    let totalPoints: Int
    let timeStats: TimeStats?
    let byTemplate: [String: TemplateStats]
    let animate: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                Text("积分收获")
                    .font(.headline)
                Spacer()
                Text("总计 +\(totalPoints)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
            }

            if let stats = timeStats {
                HStack(spacing: 8) {
                    PointsTimeCard(title: "本周", points: stats.thisWeek.points)
                    PointsTimeCard(title: "本月", points: stats.thisMonth.points)
                    PointsTimeCard(title: "今年", points: stats.thisYear.points)
                }
            }

            // 积分来源排名
            let topTemplates = byTemplate.sorted { ($0.value.points ?? 0) > ($1.value.points ?? 0) }.prefix(5)
            if !topTemplates.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("积分来源")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    ForEach(Array(topTemplates.enumerated()), id: \.offset) { index, item in
                        HStack {
                            Text("\(index + 1).")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 20)
                            Text(item.key)
                                .font(.caption)
                                .lineLimit(1)
                            Spacer()
                            Text("+\(item.value.points ?? 0)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.green)
                        }
                    }
                }
                .padding(12)
                .background(Color(.systemGray6))
                .cornerRadius(10)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        .opacity(animate ? 1 : 0)
        .animation(.easeInOut(duration: 0.5).delay(0.5), value: animate)
    }
}

struct PointsTimeCard: View {
    let title: String
    let points: Int

    var body: some View {
        VStack(spacing: 4) {
            Text("+\(points)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.green)
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.green.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - 各项目详情

struct TemplateDetailsSection: View {
    let templates: [(name: String, stats: TemplateStats)]
    let onTap: () -> Void
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
                ForEach(Array(templates.enumerated()), id: \.offset) { index, item in
                    TemplateRow(name: item.name, stats: item.stats, onTap: onTap)
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

struct TemplateRow: View {
    let name: String
    let stats: TemplateStats
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
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

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(10)
        }
    }
}

// MARK: - 今日打卡状态

struct TodayCheckInSection: View {
    let items: [CheckInItem]
    let getStatus: (CheckInItem) -> CheckInStatus
    let animate: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("今日打卡")
                    .font(.headline)
                Spacer()
            }

            HStack(spacing: 12) {
                ForEach(items) { item in
                    TodayCheckInCard(item: item, status: getStatus(item))
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
        .scaleEffect(animate ? 1 : 0.95)
        .opacity(animate ? 1 : 0)
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: animate)
    }
}

struct TodayCheckInCard: View {
    let item: CheckInItem
    let status: CheckInStatus

    var body: some View {
        VStack(spacing: 8) {
            // 图标
            ZStack {
                Circle()
                    .fill(item.color.opacity(0.15))
                    .frame(width: 44, height: 44)

                Image(systemName: item.icon)
                    .font(.system(size: 20))
                    .foregroundColor(item.color)
            }

            // 名称
            Text(item.displayName)
                .font(.caption)
                .fontWeight(.medium)

            // 状态
            HStack(spacing: 3) {
                Image(systemName: status.icon)
                    .font(.system(size: 10))
                Text(status.displayText)
                    .font(.caption2)
            }
            .foregroundColor(status.color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(status == .approved ? Color.green.opacity(0.1) : Color(.systemGray6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(status == .approved ? Color.green.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }
}

// MARK: - 辅助视图

struct LoadingView: View {
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("加载中...")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }
}

struct ErrorView: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Button("重试", action: retry)
                .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

#Preview {
    NavigationStack {
        DashboardView()
            .navigationTitle("仪表盘")
    }
}
