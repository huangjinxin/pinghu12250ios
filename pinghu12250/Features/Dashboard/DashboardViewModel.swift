//
//  DashboardViewModel.swift
//  pinghu12250
//
//  仪表盘 ViewModel - 全量统计

import Foundation
import SwiftUI
import Combine

@MainActor
class DashboardViewModel: ObservableObject {
    // MARK: - 时间范围选择

    @Published var selectedRange: DashboardTimeRange = .month

    // MARK: - 今日打卡状态

    @Published var todayStatus: [String: CheckInStatus] = [:]
    @Published var queryDate: String = ""

    // MARK: - 每日挑战奖励状态

    @Published var rewardStatus: DailyRewardStatus?
    @Published var isClaimingReward = false
    @Published var claimError: String?
    @Published var showClaimSuccess = false
    @Published var claimedRewardData: ClaimRewardData?

    // MARK: - 用户信息

    @Published var joinedDays: Int = 0
    @Published var approvalStreak: Int = 0

    // MARK: - 汇总统计

    @Published var summary: FullSummary?

    // MARK: - 各维度统计

    @Published var byTemplate: [String: TemplateStats] = [:]
    @Published var byRequirement: RequirementStats?
    @Published var byRuleType: [String: RuleTypeStats] = [:]
    @Published var timeStats: TimeStats?

    // MARK: - 趋势和热力图

    @Published var trend: [TrendItem] = []
    @Published var heatmap: [HeatmapItem] = []

    // MARK: - 加载状态

    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - 时区

    private var timezoneOffset: Int {
        -(TimeZone.current.secondsFromGMT() / 60)
    }

    // MARK: - 加载所有数据

    func loadData() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        // 并行加载今日状态、全量统计和奖励状态
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadTodayStatus() }
            group.addTask { await self.loadFullStats() }
            group.addTask { await self.loadRewardStatus() }
        }
    }

    // MARK: - 加载今日打卡状态

    private func loadTodayStatus() async {
        do {
            let templateNames = CheckInItem.templateNames
                .addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? ""
            let endpoint = "\(APIConfig.Endpoints.todayStatus)?templateNames=\(templateNames)&timezoneOffset=\(timezoneOffset)"

            let response: TodayStatusResponse = try await APIService.shared.get(endpoint)

            queryDate = response.queryDate

            // 转换为 CheckInStatus
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
            todayStatus = statusMap

        } catch {
            #if DEBUG
            print("📅 加载今日状态失败: \(error)")
            #endif
        }
    }

    // MARK: - 加载全量统计

    private func loadFullStats() async {
        do {
            let endpoint = "\(APIConfig.Endpoints.fullDashboardStats)?range=\(selectedRange.rawValue)&timezoneOffset=\(timezoneOffset)"

            #if DEBUG
            print("📊 Full Dashboard API: \(endpoint)")
            #endif

            let response: FullDashboardResponse = try await APIService.shared.get(endpoint)

            #if DEBUG
            print("📊 加载成功: total=\(response.summary.total), streak=\(response.userInfo.approvalStreak)")
            #endif

            // 更新数据
            joinedDays = response.userInfo.joinedDays
            approvalStreak = response.userInfo.approvalStreak
            summary = response.summary
            byTemplate = response.byTemplate
            byRequirement = response.byRequirement
            byRuleType = response.byRuleType
            timeStats = response.timeStats
            trend = response.trend
            heatmap = response.heatmap

        } catch {
            #if DEBUG
            print("📊 加载失败: \(error)")
            #endif
            errorMessage = "加载统计数据失败"
        }
    }

    /// 获取指定项目的今日状态
    func getStatus(for item: CheckInItem) -> CheckInStatus {
        todayStatus[item.id] ?? .notSubmitted
    }

    // MARK: - 切换时间范围

    func changeRange(_ range: DashboardTimeRange) {
        selectedRange = range
        Task {
            await loadData()
        }
    }

    // MARK: - 辅助方法

    /// 获取状态分布饼图数据
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

    /// 获取提交类型分布数据
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

    /// 获取技术类型分布数据
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

    /// 获取项目排名（按提交数量）
    func getTopTemplates(limit: Int = 10) -> [(name: String, stats: TemplateStats)] {
        byTemplate
            .sorted { $0.value.total > $1.value.total }
            .prefix(limit)
            .map { ($0.key, $0.value) }
    }

    /// 跳转到我的提交
    func navigateToMySubmissions() {
        NotificationCenter.default.post(
            name: .switchToGrowthTab,
            object: nil,
            userInfo: ["tabIndex": 2]  // 2 = 我的提交
        )
    }

    // MARK: - 每日挑战奖励

    /// 加载奖励状态
    private func loadRewardStatus() async {
        do {
            let endpoint = "\(APIConfig.Endpoints.dailyRewardStatus)?timezoneOffset=\(timezoneOffset)"

            #if DEBUG
            print("🎁 Loading reward status: \(endpoint)")
            #endif

            let response: DailyRewardStatusResponse = try await APIService.shared.get(endpoint)
            rewardStatus = response.data

            #if DEBUG
            print("🎁 Reward status loaded: canClaim=\(response.data.canClaim), claimed=\(response.data.claimed), approved=\(response.data.approvedCount)/\(response.data.requiredCount)")
            #endif

        } catch {
            #if DEBUG
            print("🎁 加载奖励状态失败: \(error)")
            #endif
        }
    }

    /// 领取奖励
    func claimReward() async {
        guard let status = rewardStatus, status.canClaim else { return }

        isClaimingReward = true
        claimError = nil
        defer { isClaimingReward = false }

        do {
            let endpoint = APIConfig.Endpoints.claimDailyReward
            let body = ClaimRewardRequest(timezoneOffset: timezoneOffset)

            let response: ClaimRewardResponse = try await APIService.shared.post(endpoint, body: body)
            claimedRewardData = response.data
            showClaimSuccess = true

            // 刷新奖励状态
            await loadRewardStatus()

            #if DEBUG
            print("🎁 领取成功: \(response.data.totalPoints) 积分")
            #endif

        } catch let error as APIError {
            claimError = error.localizedDescription
            #if DEBUG
            print("🎁 领取失败: \(error)")
            #endif
        } catch {
            claimError = "领取失败，请稍后重试"
            #if DEBUG
            print("🎁 领取失败: \(error)")
            #endif
        }
    }

    /// 今日完成数量
    var completedCount: Int {
        todayStatus.values.filter { $0 == .approved }.count
    }

    /// 今日获得积分（仅审核通过的项目）
    var todayPoints: Int {
        var points = 0
        for item in CheckInItem.allItems {
            if getStatus(for: item) == .approved {
                points += item.points
            }
        }
        return points
    }
}
