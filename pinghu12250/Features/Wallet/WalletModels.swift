//
//  WalletModels.swift
//  pinghu12250
//
//  钱包和支付相关数据模型
//

import Foundation

// MARK: - 钱包

struct Wallet: Codable {
    let id: String?
    let userId: String?
    let balance: FlexibleDouble // 使用 FlexibleDouble 支持字符串或数字解析
    let createdAt: String?
    let updatedAt: String?

    var balanceValue: Double {
        balance.value
    }
}

struct WalletResponse: Decodable {
    let wallet: Wallet?
    let balance: FlexibleDouble? // 也支持直接返回 balance
}

// MARK: - 钱包交易记录

struct WalletTransaction: Codable, Identifiable {
    let id: String
    let walletId: String?
    let amount: Double
    let type: String
    let description: String?
    let relatedType: String?
    let relatedId: String?
    let createdAt: String?

    var isPositive: Bool {
        amount >= 0
    }

    var displayAmount: String {
        amount >= 0 ? "+\(String(format: "%.2f", amount))" : String(format: "%.2f", amount)
    }
}

struct WalletTransactionsResponse: Decodable {
    let transactions: [WalletTransaction]
    let pagination: PaginationInfo?
}

// MARK: - 收款码

struct PayCode: Codable, Identifiable {
    let id: String
    let code: String
    let title: String
    let amount: Double
    let description: String?
    let category: String?
    let isActive: Bool?
    let createdAt: String?
}

struct PayCodeResponse: Decodable {
    let payCode: PayCode
}

// MARK: - 支付订单

struct PayOrder: Codable, Identifiable {
    let id: String
    let orderNo: String
    let userId: String
    let payCodeId: String
    let amount: FlexibleDouble  // 支持字符串或数字
    let title: String
    let status: String
    let createdAt: String?
    let payCode: PayCodeInfo?  // 简化版 payCode 信息

    var amountValue: Double {
        amount.value
    }
}

// 简化版 PayCode 信息（只包含 my-orders API 返回的字段）
struct PayCodeInfo: Codable {
    let title: String?
    let description: String?
}

// 注意: FlexibleDouble 已移至 Core/Models/CommonTypes.swift

struct PayOrdersResponse: Decodable {
    let orders: [PayOrder]
    let pagination: PaginationInfo?
}

// MARK: - 支付请求

struct PaymentSubmitRequest: Encodable {
    let payCodeId: String
    let paymentPassword: String
}

struct PaymentSubmitResponse: Decodable {
    let order: PayOrder?
    let message: String?
}

// MARK: - 积分兑换

struct ExchangeConfigResponse: Decodable {
    let pointsPerCoin: Int?
    let dailyLimit: Int?
    let minPoints: Int?
    let rate: ExchangeRate?
    let remainingLimit: Int?
    let todayUsed: Int?

    struct ExchangeRate: Decodable {
        let points: Int?
        let coins: Int?
    }
}

struct ExchangeRequest: Encodable {
    let points: Int
}

struct ExchangeResponse: Decodable {
    let coinsAdded: Double?
    let newBalance: Double?
    let message: String?
}

// MARK: - 积分明细

struct PointLog: Codable, Identifiable {
    let id: String
    let userId: String?
    let points: Int
    let description: String?
    let targetType: String?
    let targetId: String?
    let ruleId: String?
    let ruleName: String?
    let createdAt: String?
    // /points/records 接口返回的字段
    let actionKey: String?
    let actionName: String?

    var displayDescription: String {
        description ?? actionName ?? ruleName ?? "积分变动"
    }

    var isPositive: Bool {
        points >= 0
    }

    var displayPoints: String {
        points >= 0 ? "+\(points)" : "\(points)"
    }
}

struct PointLogsResponse: Decodable {
    let records: [PointLog]? // /points/records 返回 records 字段
    let logs: [PointLog]? // 兼容 /points/logs 返回 logs 字段
    let totalPoints: Int?
    let availablePoints: Int?
    let pagination: PaginationInfo?

    // 统一获取数据的方法
    var allLogs: [PointLog] {
        records ?? logs ?? []
    }
}

// MARK: - 兑换记录

struct ExchangeRecord: Codable, Identifiable {
    let id: String
    let userId: String?
    let pointsSpent: Int
    let coinsGained: Double
    let exchangeRate: String?
    let createdAt: String?
}

struct ExchangeHistoryResponse: Decodable {
    let exchanges: [ExchangeRecord]?
    let pagination: PaginationInfo?
}

// MARK: - 积分排行榜

struct LeaderboardUser: Codable, Identifiable {
    let id: String
    let username: String?
    let displayName: String?
    let avatar: String?
    let totalPoints: Int?

    var displayUsername: String {
        displayName ?? username ?? "用户"
    }

    var avatarInitial: String {
        String(displayUsername.prefix(1))
    }
}

struct PointsLeaderboardResponse: Decodable {
    let leaderboard: [LeaderboardUser]?
}
