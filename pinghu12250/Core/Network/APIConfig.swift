//
//  APIConfig.swift
//  pinghu12250
//
//  API 配置 - 服务器地址和端点定义
//

import Foundation

/// API 配置
enum APIConfig {
    // MARK: - 服务器地址

    /// 本地开发环境（HTTP，无需 SSL）
    static let localBaseURL = "http://192.168.88.228:12251/api"

    /// 生产环境
    static let productionBaseURL = "https://pinghu.706tech.cn/api"

    /// Tailscale VPN 内网
    static let tailscaleBaseURL = "https://beichenmac-mini-3.tail2b26f.ts.net/api"

    /// 动态 BaseURL - 从 UserDefaults 读取用户配置
    static var baseURL: String {
        // 优先使用用户配置的地址
        if let customURL = UserDefaults.standard.string(forKey: "activeServerURL"),
           !customURL.isEmpty {
            return customURL
        }

        // 默认使用本地 HTTP（开发环境，简单稳定）
        return localBaseURL
    }

    /// 更新服务器地址
    static func updateBaseURL(_ url: String) {
        UserDefaults.standard.set(url, forKey: "activeServerURL")
    }

    // MARK: - API 端点

    enum Endpoints {
        // 认证
        static let login = "/auth/login"
        static let register = "/auth/register"
        static let refreshToken = "/auth/refresh"
        static let verifyTwoFactor = "/auth/verify-2fa"
        static let deleteAccount = "/auth/delete-account"

        // 两步验证
        static let twoFactorStatus = "/2fa/status"

        // 用户
        static let currentUser = "/users/me"
        static let updateProfile = "/users/me"

        // 教材
        static let textbooks = "/textbooks/public"
        static let textbookOptions = "/textbooks/options"
        static let textbookDetail = "/textbooks" // + /{id}
        static let textbookPdf = "/textbooks" // + /{id}/pdf
        static let textbookFavorites = "/textbooks/favorites"

        // 笔记
        static let textbookNotes = "/textbook-notes"

        // AI 分析
        static let aiChat = "/ai-analysis/chat"
        static let aiChatStream = "/ai-analysis/chat/stream"
        static let aiConfig = "/ai-config"
        static let aiPrompts = "/ai-prompts"
        static let aiPromptsSystem = "/ai-prompts/system"

        // 奖罚规则
        static let ruleTemplates = "/rules/templates/active"
        static let ruleTypes = "/rules/types"
        static let ruleStandards = "/rules/standards"

        // 提交管理
        static let submissions = "/submissions"
        static let mySubmissions = "/submissions/my"
        static let todayStatus = "/submissions/my/today-status"
        static let dashboardStats = "/submissions/my/dashboard-stats"
        static let fullDashboardStats = "/submissions/my/full-stats"
        static let templateFavorites = "/submissions/favorites"
        static let checkTemplateFavorites = "/submissions/favorites/check"

        // 每日挑战奖励
        static let challengeConfig = "/submissions/challenge-config"
        static let dailyRewardStatus = "/submissions/daily-reward/status"
        static let claimDailyReward = "/submissions/daily-reward/claim"

        // 钱包
        static let wallet = "/wallet"
        static let walletTransactions = "/wallet/transactions"

        // 积分
        static let pointsMy = "/points/my"
        static let pointsLogs = "/points/records" // 使用 /records 接口与 web 保持一致
        static let pointsExchange = "/points/exchange"
        static let pointsExchangeConfig = "/points/exchange/config"
        static let pointsExchangeHistory = "/points/exchange/history"
        static let pointsLeaderboard = "/points/leaderboard"

        // 支付
        static let payScan = "/pay/scan"      // + /{code}
        static let paySubmit = "/pay/submit"
        static let payOrders = "/pay/my-orders"
        static let payPublicCodes = "/pay/public/codes"

        // 教材
        static let textbooksPublic = "/textbooks/public"
        static let textbooksToc = "/textbooks/public" // + /:id/toc
        static let textbooksLesson = "/textbooks/public/lesson" // + /:id
        static let textbooksNotes = "/textbook-notes"

        // 画廊
        static let galleryWorks = "/gallery"
        static let galleryPublic = "/gallery/public"
        static let galleryTypes = "/gallery/types"
        static let galleryStandards = "/gallery/standards"

        // 朗诵
        static let recitationWorks = "/gallery/recitation"
        static let recitationPublic = "/gallery/recitation/public"

        // 唐诗宋词
        static let poetryWorks = "/poetry-works"
        static let poetryPublic = "/poetry-works/public"

        // 创意作品（动态栏目）
        static let creativeWorksPublic = "/creative-works/public"
        static let creativeWorksPublicDetail = "/creative-works"  // + /{id}

        // 购物
        static let marketWorks = "/market/works"
        static let marketMyPurchases = "/market/my-purchases"

        // 文件上传
        static let upload = "/upload"

        // 日记
        static let diaries = "/diaries"

        // 日记 AI 分析
        static let diaryAnalyze = "/ai-analysis/diary/analyze"
        static let diaryAnalyzeBatch = "/ai-analysis/diary/analyze-batch"
        static let diaryAnalysisSave = "/ai-analysis/diary/save"
        static let diaryAnalysisHistory = "/ai-analysis/diary/history"
        static let diaryAnalysisPublic = "/ai-analysis/diary/public"  // 公开日记分析（作品广场）
        static let diaryAnalysisPublicDetail = "/ai-analysis/diary/public"  // + /{id}

        // 日记游戏化
        static let diaryGameStats = "/diary-game/stats"
        static let diaryGameAchievements = "/diary-game/achievements"
        static let diaryGameAchievementsStats = "/diary-game/achievements/stats"
        static let diaryGameConfig = "/diary-game/config"
        static let diaryGameOverview = "/diary-game/overview"

        // 字典
        static let dict = "/dict"  // + /{char}

        // 书写评价
        static let writingEvaluation = "/writing-evaluation"  // + /{noteId}/status, /{noteId}, /analyze

        // 字体管理
        static let fonts = "/fonts"
        static let fontDetail = "/fonts"  // + /{id}
        static let fontDefault = "/fonts"  // + /{id}/default
        static let fontFile = "/fonts"  // + /{id}/file

        // 书写作品
        static let calligraphy = "/calligraphy"
        static let calligraphyMy = "/calligraphy/my"
        static let calligraphyDetail = "/calligraphy"  // + /{id}
        static let calligraphyLike = "/calligraphy"  // + /{id}/like

        // 公开接口
        static let unifiedFeed = "/public/unified-feed"
        static let worksFeed = "/public/works-feed"
        static let leaderboard = "/public/leaderboard"
    }

    // MARK: - 请求超时

    static let requestTimeout: TimeInterval = 30
    static let aiAnalysisTimeout: TimeInterval = 600 // 10分钟用于AI分析（批量周分析需要较长时间）
    static let uploadTimeout: TimeInterval = 300 // 5分钟用于上传大文件
}
