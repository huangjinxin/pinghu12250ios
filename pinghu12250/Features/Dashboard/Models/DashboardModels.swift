//
//  DashboardModels.swift
//  pinghu12250
//
//  仪表盘数据模型

import Foundation
import SwiftUI

// MARK: - 全量统计响应

struct FullDashboardResponse: Decodable {
    let userInfo: UserInfo
    let summary: FullSummary
    let byTemplate: [String: TemplateStats]
    let byRequirement: RequirementStats
    let byRuleType: [String: RuleTypeStats]
    let timeStats: TimeStats
    let trend: [TrendItem]
    let heatmap: [HeatmapItem]
    let queryRange: QueryRange
}

struct UserInfo: Decodable {
    let joinedDays: Int
    let approvalStreak: Int
}

struct FullSummary: Decodable {
    let total: Int
    let approved: Int
    let pending: Int
    let rejected: Int
    let totalPoints: Int
    let passRate: Int
}

struct TemplateStats: Decodable {
    let templateId: String?
    let approved: Int
    let pending: Int
    let rejected: Int
    let total: Int
    let points: Int?

    // 为了兼容旧 API
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        templateId = try container.decodeIfPresent(String.self, forKey: .templateId)
        approved = try container.decode(Int.self, forKey: .approved)
        pending = try container.decode(Int.self, forKey: .pending)
        rejected = try container.decode(Int.self, forKey: .rejected)
        total = try container.decode(Int.self, forKey: .total)
        points = try container.decodeIfPresent(Int.self, forKey: .points)
    }

    enum CodingKeys: String, CodingKey {
        case templateId, approved, pending, rejected, total, points
    }
}

struct RequirementStats: Decodable {
    let image: RequirementItem
    let audio: RequirementItem
    let link: RequirementItem
    let text: RequirementItem
}

struct RequirementItem: Decodable {
    let total: Int
    let approved: Int
    let points: Int
}

struct RuleTypeStats: Decodable {
    let typeId: String?
    let approved: Int
    let pending: Int
    let rejected: Int
    let total: Int
    let points: Int
}

struct TimeStats: Decodable {
    let today: TimePeriodStats
    let thisWeek: TimePeriodStats
    let thisMonth: TimePeriodStats
    let thisYear: TimePeriodStats
}

struct TimePeriodStats: Decodable {
    let submitted: Int
    let approved: Int
    let points: Int
}

struct TrendItem: Decodable, Identifiable {
    let date: String
    let submitted: Int
    let approved: Int
    let pending: Int
    let rejected: Int
    let points: Int?

    var id: String { date }

    // 用于图表显示的简短日期
    var shortDate: String {
        let parts = date.split(separator: "-")
        guard parts.count == 3 else { return date }
        return "\(parts[1])/\(parts[2])"
    }

    // 为了兼容旧 API
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        date = try container.decode(String.self, forKey: .date)
        submitted = try container.decode(Int.self, forKey: .submitted)
        approved = try container.decode(Int.self, forKey: .approved)
        pending = try container.decode(Int.self, forKey: .pending)
        rejected = try container.decode(Int.self, forKey: .rejected)
        points = try container.decodeIfPresent(Int.self, forKey: .points)
    }

    enum CodingKeys: String, CodingKey {
        case date, submitted, approved, pending, rejected, points
    }
}

struct HeatmapItem: Decodable, Identifiable {
    let date: String
    let count: Int
    let approved: Int

    var id: String { date }

    // 热力等级 (0-4)
    var level: Int {
        if count == 0 { return 0 }
        if count <= 1 { return 1 }
        if count <= 3 { return 2 }
        if count <= 5 { return 3 }
        return 4
    }
}

struct QueryRange: Decodable {
    let range: String?
    let start: String?
    let end: String
    let days: Int?
}

// MARK: - 时间范围选项

enum DashboardTimeRange: String, CaseIterable, Identifiable {
    case week = "7"
    case month = "30"
    case quarter = "90"
    case year = "365"
    case all = "all"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .week: return "本周"
        case .month: return "本月"
        case .quarter: return "近3月"
        case .year: return "今年"
        case .all: return "全部"
        }
    }
}

// MARK: - 图表数据模型

struct ChartDataPoint: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
    let color: Color
}

struct PieSlice: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
    let color: Color
    let percentage: Double
}

// MARK: - 旧 API 兼容（今日状态）

struct TodayStatusResponse: Decodable {
    let todayStatus: [String: TodayStatusItem?]
    let queryDate: String
}

struct TodayStatusItem: Decodable {
    let status: String
    let submissionId: String
    let createdAt: String
}

// MARK: - 旧版统计响应（保留兼容）

struct DashboardStatsResponse: Decodable {
    let summary: StatsSummary
    let byTemplate: [String: TemplateStats]
    let trend: [TrendItem]
    let streak: Int
    let queryRange: QueryRange
}

struct StatsSummary: Decodable {
    let total: Int
    let approved: Int
    let pending: Int
    let rejected: Int
    let missing: Int
    let passRate: Int
}

// MARK: - 打卡项目配置（保留用于今日打卡）

struct CheckInItem: Identifiable {
    let id: String
    let displayName: String
    let templateName: String
    let icon: String
    let color: Color
    let points: Int
    let description: String

    static let diary = CheckInItem(
        id: "diary",
        displayName: "日记",
        templateName: "日记(审批前提项/日)",
        icon: "book.closed.fill",
        color: .purple,
        points: 200,
        description: "记录今天的所思所想，不少于800字"
    )

    static let math = CheckInItem(
        id: "math",
        displayName: "数学",
        templateName: "可汗学院数学进度",
        icon: "function",
        color: .blue,
        points: 60,
        description: "完成可汗学院数学课程并截图"
    )

    static let poetry = CheckInItem(
        id: "poetry",
        displayName: "背诗",
        templateName: "背诗",
        icon: "text.book.closed.fill",
        color: .orange,
        points: 55,
        description: "背诵一首古诗并录音提交"
    )

    static let allItems: [CheckInItem] = [diary, math, poetry]

    static var templateNames: String {
        allItems.map { $0.templateName }.joined(separator: ",")
    }
}

// MARK: - 打卡状态枚举

enum CheckInStatus: String {
    case notSubmitted = "NOT_SUBMITTED"
    case pending = "PENDING"
    case approved = "APPROVED"
    case rejected = "REJECTED"

    var displayText: String {
        switch self {
        case .notSubmitted: return "未提交"
        case .pending: return "待审核"
        case .approved: return "已通过"
        case .rejected: return "已退回"
        }
    }

    var icon: String {
        switch self {
        case .notSubmitted: return "circle.dashed"
        case .pending: return "clock.fill"
        case .approved: return "checkmark.circle.fill"
        case .rejected: return "xmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .notSubmitted: return .gray
        case .pending: return .orange
        case .approved: return .green
        case .rejected: return .red
        }
    }

    init(from statusString: String?) {
        guard let status = statusString else {
            self = .notSubmitted
            return
        }
        self = CheckInStatus(rawValue: status) ?? .notSubmitted
    }
}

// MARK: - 每日挑战奖励模型

/// 挑战配置响应
struct ChallengeConfigResponse: Decodable {
    let success: Bool
    let data: ChallengeConfig
}

/// 挑战配置
struct ChallengeConfig: Decodable {
    let basePoints: Int
    let streakBonus: Int
    let streakMaxDays: Int
}

/// 每日奖励状态响应
struct DailyRewardStatusResponse: Decodable {
    let success: Bool
    let data: DailyRewardStatus
}

/// 每日奖励状态
struct DailyRewardStatus: Decodable {
    let date: String
    let approvedCount: Int
    let requiredCount: Int
    let canClaim: Bool
    let claimed: Bool
    let claimedReward: ClaimedReward?
    let estimatedReward: EstimatedReward?
    let config: ChallengeConfig
}

/// 已领取的奖励
struct ClaimedReward: Decodable {
    let basePoints: Int
    let streakDays: Int
    let streakPoints: Int
    let totalPoints: Int
    let claimedAt: String
}

/// 预估奖励
struct EstimatedReward: Decodable {
    let basePoints: Int
    let streakDays: Int
    let streakPoints: Int
    let totalPoints: Int
}

/// 领取奖励响应
struct ClaimRewardResponse: Decodable {
    let success: Bool
    let data: ClaimRewardData
}

/// 领取奖励数据
struct ClaimRewardData: Decodable {
    let basePoints: Int
    let streakDays: Int
    let streakPoints: Int
    let totalPoints: Int
    let message: String
}

/// 领取奖励请求体
struct ClaimRewardRequest: Encodable {
    let timezoneOffset: Int
}
