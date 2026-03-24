//
//  APIConfig.swift
//  pinghu12250
//
//  API 配置 - 服务器地址和端点定义
//

import Foundation
import Combine

/// API 配置
enum APIConfig {
    // MARK: - 服务器地址

    /// 本地开发环境（HTTP，无需 SSL）
    static let localBaseURL = "http://192.168.88.228:12251"

    /// 生产环境
    static let productionBaseURL = "https://kids.706tech.cn"

    /// Tailscale VPN 内网
    static let tailscaleBaseURL = "https://beichenmac-mini-3.tail2b26f.ts.net"

    static func normalizedBaseURL(_ url: String) -> String {
        var value = url.trimmingCharacters(in: .whitespacesAndNewlines)
        while value.hasSuffix("/") {
            value.removeLast()
        }
        if value.hasSuffix("/api") {
            value.removeLast(4)
        }
        return value
    }

    /// 动态 BaseURL - 从 UserDefaults 读取用户配置
    static var baseURL: String {
        if let customURL = UserDefaults.standard.string(forKey: "activeServerURL"), !customURL.isEmpty {
            return normalizedBaseURL(customURL)
        }
        return localBaseURL
    }

    /// Socket.IO URL
    static var socketURL: String {
        return baseURL
    }

    /// 更新服务器地址
    static func updateBaseURL(_ url: String) {
        UserDefaults.standard.set(normalizedBaseURL(url), forKey: "activeServerURL")
    }

    // MARK: - API 端点

    enum Endpoints {
        // 认证
        static let login = "/api/auth/login"
        static let register = "/api/auth/register"
        static let refreshToken = "/api/auth/refresh"
        static let verifyTwoFactor = "/api/auth/verify-2fa"
        static let deleteAccount = "/api/auth/delete-account"

        // 两步验证
        static let twoFactorStatus = "/api/2fa/status"

        // 用户
        static let currentUser = "/api/users/me"
        static let updateProfile = "/api/users/me"

        // 教材
        static let textbooks = "/api/textbooks/public"
        static let textbookOptions = "/api/textbooks/options"
        static let textbookDetail = "/api/textbooks" // + /{id}
        static let textbookPdf = "/api/textbooks" // + /{id}/pdf
        static let textbookFavorites = "/api/textbooks/favorites"

        // 笔记
        static let textbookNotes = "/api/textbook-notes"

        // AI 分析
        static let aiChat = "/api/ai-analysis/chat"
        static let aiChatStream = "/api/ai-analysis/chat/stream"
        static let aiConfig = "/api/ai-config"
        static let aiPrompts = "/api/ai-prompts"
        static let aiPromptsSystem = "/api/ai-prompts/system"

        // 奖罚规则
        static let ruleTemplates = "/api/rules/templates/active"
        static let ruleTypes = "/api/rules/types"
        static let ruleStandards = "/api/rules/standards"

        // 提交管理
        static let submissions = "/api/submissions"
        static let mySubmissions = "/api/submissions/my"
        static let todayStatus = "/api/submissions/my/today-status"
        static let dashboardStats = "/api/submissions/my/dashboard-stats"
        static let fullDashboardStats = "/api/submissions/my/full-stats"
        static let templateFavorites = "/api/submissions/favorites"
        static let checkTemplateFavorites = "/api/submissions/favorites/check"

        // 每日挑战奖励
        static let challengeConfig = "/api/submissions/challenge-config"
        static let dailyRewardStatus = "/api/submissions/daily-reward/status"
        static let claimDailyReward = "/api/submissions/daily-reward/claim"

        // 钱包
        static let wallet = "/api/wallet"
        static let walletTransactions = "/api/wallet/transactions"

        // 积分
        static let pointsMy = "/api/points/my"
        static let pointsLogs = "/api/points/records"
        static let pointsExchange = "/api/points/exchange"
        static let pointsExchangeConfig = "/api/points/exchange/config"
        static let pointsExchangeHistory = "/api/points/exchange/history"
        static let pointsLeaderboard = "/api/points/leaderboard"

        // 支付
        static let payScan = "/api/pay/scan"      // + /{code}
        static let paySubmit = "/api/pay/submit"
        static let payOrders = "/api/pay/my-orders"
        static let payPublicCodes = "/api/pay/public/codes"

        // 教材
        static let textbooksPublic = "/api/textbooks/public"
        static let textbooksToc = "/api/textbooks/public" // + /:id/toc
        static let textbooksLesson = "/api/textbooks/public/lesson" // + /:id
        static let textbooksNotes = "/api/textbook-notes"

        // 画廊
        static let galleryWorks = "/api/gallery"
        static let galleryPublic = "/api/gallery/public"
        static let galleryTypes = "/api/gallery/types"
        static let galleryStandards = "/api/gallery/standards"

        // 朗诵
        static let recitationWorks = "/api/gallery/recitation"
        static let recitationPublic = "/api/gallery/recitation/public"

        // 唐诗宋词
        static let poetryWorks = "/api/poetry-works"
        static let poetryPublic = "/api/poetry-works/public"

        // 创意作品（动态栏目）
        static let creativeWorksPublic = "/api/creative-works/public"
        static let creativeWorksPublicDetail = "/api/creative-works"  // + /{id}

        // 购物
        static let marketWorks = "/api/market/works"
        static let marketMyPurchases = "/api/market/my-purchases"

        // 文件上传
        static let upload = "/api/upload"

        // 日记
        static let diaries = "/api/diaries"

        // 日记 AI 分析
        static let diaryAnalyze = "/api/ai-analysis/diary/analyze"
        static let diaryAnalyzeBatch = "/api/ai-analysis/diary/analyze-batch"
        static let diaryAnalysisSave = "/api/ai-analysis/diary/save"
        static let diaryAnalysisHistory = "/api/ai-analysis/diary/history"
        static let diaryAnalysisPublic = "/api/ai-analysis/diary/public"
        static let diaryAnalysisPublicDetail = "/api/ai-analysis/diary/public"  // + /{id}

        // 日记游戏化
        static let diaryGameStats = "/api/diary-game/stats"
        static let diaryGameAchievements = "/api/diary-game/achievements"
        static let diaryGameAchievementsStats = "/api/diary-game/achievements/stats"
        static let diaryGameConfig = "/api/diary-game/config"
        static let diaryGameOverview = "/api/diary-game/overview"

        // 字典
        static let dict = "/api/dict"  // + /{char}

        // 书写评价
        static let writingEvaluation = "/api/writing-evaluation"

        // 字体管理
        static let fonts = "/api/fonts"
        static let fontDetail = "/api/fonts"  // + /{id}
        static let fontDefault = "/api/fonts"  // + /{id}/default
        static let fontFile = "/api/fonts"  // + /{id}/file

        // 书写作品
        static let calligraphy = "/api/calligraphy"
        static let calligraphyMy = "/api/calligraphy/my"
        static let calligraphyDetail = "/api/calligraphy"  // + /{id}
        static let calligraphyLike = "/api/calligraphy"  // + /{id}/like

        // Bot 聊天
        static let bots = "/api/bot"
        static let chatConversations = "/api/chat-message/conversations"
        static let chatMessages = "/api/chat-message"  // + /{botId}/messages
        static let chatSend = "/api/chat-message"       // + /{botId}/send
        static let chatRead = "/api/chat-message"       // + /{conversationId}/read
        static let scan = "/api/scan"

        // IM 聊天
        static let imConversations = "/api/messages/conversations/list"
        static let imMessages = "/api/messages"  // + /{userId}
        static let imMarkRead = "/api/messages/mark-chat-read"
        static let imUnreadCount = "/api/unread-count"

        // 好友系统
        static let users = "/api/users"
        static let friendRequests = "/api/friend-requests"
        static let follows = "/api/follows"

        // 公开接口
        static let unifiedFeed = "/api/public/unified-feed"
        static let worksFeed = "/api/public/works-feed"
        static let leaderboard = "/api/public/leaderboard"
    }

    // MARK: - 请求超时

    static let requestTimeout: TimeInterval = 30
    static let aiAnalysisTimeout: TimeInterval = 600 // 10分钟用于AI分析（批量周分析需要较长时间）
    static let uploadTimeout: TimeInterval = 300 // 5分钟用于上传大文件
}
