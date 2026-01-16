//
//  DiaryModels.swift
//  pinghu12250
//
//  日记数据模型 - 匹配后端 API
//

import Foundation
import SwiftUI
import Combine

// MARK: - 日记模版

enum DiaryTemplate {
    static let timelineTemplate = """
【清晨】

【起床】

【洗漱穿衣】

【早饭】

【上午】

【中午】

【午饭】

【午休】

【下午】

【傍晚】

【晚饭】

【天黑】

【晚上】

【回家】

【睡觉】
"""
}

// MARK: - 日记草稿

struct DiaryDraft: Identifiable, Codable {
    let id: String
    var title: String
    var content: String
    var mood: String
    var weather: String
    var savedAt: Date

    init(id: String = UUID().uuidString, title: String = "", content: String = "", mood: String = "happy", weather: String = "sunny", savedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.content = content
        self.mood = mood
        self.weather = weather
        self.savedAt = savedAt
    }

    var hasContent: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var wordCount: Int {
        content.count
    }
}

// MARK: - 草稿管理器

@MainActor
class DiaryDraftManager: ObservableObject {
    static let shared = DiaryDraftManager()

    @Published var drafts: [DiaryDraft] = []

    private let storageKey = "diary_drafts"

    private init() {
        loadDrafts()
    }

    func loadDrafts() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([DiaryDraft].self, from: data) else {
            drafts = []
            return
        }
        drafts = decoded.sorted { $0.savedAt > $1.savedAt }
    }

    private func saveDrafts() {
        if let encoded = try? JSONEncoder().encode(drafts) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }

    func saveDraft(_ draft: DiaryDraft) {
        var updatedDraft = draft
        updatedDraft.savedAt = Date()

        if let index = drafts.firstIndex(where: { $0.id == draft.id }) {
            drafts[index] = updatedDraft
        } else {
            drafts.insert(updatedDraft, at: 0)
        }
        saveDrafts()
    }

    func deleteDraft(id: String) {
        drafts.removeAll { $0.id == id }
        saveDrafts()
    }

    func clearAllDrafts() {
        drafts.removeAll()
        saveDrafts()
    }
}

// MARK: - 日记模型

struct DiaryData: Identifiable, Codable {
    let id: String
    var title: String
    var content: String
    var mood: String?
    var weather: String?
    var isPublic: Bool?
    var price: Double?
    var diaryDate: String?
    let authorId: String?
    let author: DiaryAuthor?
    let tags: [DiaryTag]?
    let createdAt: String?
    let updatedAt: String?

    // 计算属性：字数统计
    var wordCount: Int {
        content.count
    }

    var moodEmoji: String {
        DiaryData.moodOptions.first { $0.value == mood }?.emoji ?? "😊"
    }

    var weatherEmoji: String {
        DiaryData.weatherOptions.first { $0.value == weather }?.emoji ?? "☀️"
    }

    // 心情选项
    static let moodOptions: [(value: String, emoji: String, label: String)] = [
        ("happy", "😊", "开心"),
        ("neutral", "😐", "平静"),
        ("sad", "😢", "难过"),
        ("angry", "😠", "生气"),
        ("tired", "😴", "疲惫"),
    ]

    // 天气选项
    static let weatherOptions: [(value: String, emoji: String, label: String)] = [
        ("sunny", "☀️", "晴天"),
        ("cloudy", "☁️", "多云"),
        ("rainy", "🌧️", "雨天"),
        ("snowy", "❄️", "雪天"),
    ]

    // 字数等级
    var wordLevel: (level: Int, text: String, color: Color) {
        switch wordCount {
        case 2000...: return (5, "大师", .red)
        case 1500..<2000: return (4, "卓越", .orange)
        case 1200..<1500: return (3, "优秀", .blue)
        case 1000..<1200: return (2, "良好", .green)
        case 800..<1000: return (1, "入门", .green)
        default: return (0, "继续加油", .gray)
        }
    }

    // 创建日期
    var createdDate: Date? {
        guard let createdAt = createdAt else { return nil }
        let isoFormatter = ISO8601DateFormatter()
        // 先尝试带毫秒的格式
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: createdAt) {
            return date
        }
        // 再尝试不带毫秒的格式
        isoFormatter.formatOptions = [.withInternetDateTime]
        return isoFormatter.date(from: createdAt)
    }

    // 日记日期
    var diaryDateFormatted: Date? {
        guard let diaryDate = diaryDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: diaryDate)
    }
}

// MARK: - 日记作者

struct DiaryAuthor: Codable {
    let id: String?
    let username: String?
    let avatar: String?

    var displayName: String {
        username ?? "匿名"
    }

    var avatarLetter: String {
        String(displayName.prefix(1)).uppercased()
    }
}

// MARK: - 日记标签

struct DiaryTag: Codable, Identifiable {
    let id: String
    let name: String
}

// MARK: - API 响应

struct DiaryListResponse: Decodable {
    let diaries: [DiaryData]
    let pagination: DiaryPagination?
}

struct DiaryPagination: Decodable {
    let page: Int
    let limit: Int
    let total: Int

    var totalPages: Int {
        (total + limit - 1) / limit
    }
}

struct DiaryDetailResponse: Decodable {
    let diary: DiaryData
}

// MARK: - 创建/更新请求

struct CreateDiaryRequest: Encodable {
    let title: String
    let content: String
    let mood: String?
    let weather: String?
    let tags: [String]?
    let price: Double?
    let diaryDate: String?
    let isPublic: Bool?
}

struct UpdateDiaryRequest: Encodable {
    let title: String?
    let content: String?
    let mood: String?
    let weather: String?
    let tags: [String]?
    let price: Double?
    let diaryDate: String?
    let isPublic: Bool?
}

// MARK: - 评论

struct DiaryComment: Codable, Identifiable {
    let id: String
    let content: String
    let nickname: String?
    let createdAt: String?

    var displayName: String {
        nickname ?? "匿名"
    }
}

struct CreateCommentRequest: Encodable {
    let content: String
    let nickname: String?
}

struct DiaryCommentsResponse: Decodable {
    let comments: [DiaryComment]
}

// MARK: - AI 分析模型

/// AI 分析记录
struct DiaryAnalysisData: Identifiable, Codable {
    let id: String
    let userId: String?
    let isBatch: Bool
    let period: String?
    let diaryId: String?
    let diaryIds: [String]?
    let diaryCount: Int
    let diarySnapshot: DiaryAnalysisSnapshot?
    let analysis: String
    let modelName: String?
    let tokensUsed: Int?
    let responseTime: Int?
    let createdAt: String?

    /// 格式化的创建时间
    var formattedDate: String {
        guard let createdAt = createdAt else { return "" }
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: createdAt) {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM-dd HH:mm"
            return formatter.string(from: date)
        }
        // 尝试不带毫秒的格式
        isoFormatter.formatOptions = [.withInternetDateTime]
        if let date = isoFormatter.date(from: createdAt) {
            let formatter = DateFormatter()
            formatter.dateFormat = "MM-dd HH:mm"
            return formatter.string(from: date)
        }
        return ""
    }

    /// 响应时间（秒）
    var responseTimeSeconds: String {
        guard let time = responseTime else { return "" }
        return String(format: "%.1f", Double(time) / 1000.0)
    }

    /// 显示标题
    var displayTitle: String {
        if let snapshot = diarySnapshot {
            switch snapshot {
            case .single(let item):
                return item.title ?? "日记分析"
            case .batch(let items):
                return items.first?.title ?? "批量分析(\(items.count)篇)"
            }
        }
        return isBatch ? "批量分析" : "日记分析"
    }

    /// 相对时间
    var relativeTime: String {
        guard let createdAt = createdAt else { return "" }
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var date = isoFormatter.date(from: createdAt)
        if date == nil {
            isoFormatter.formatOptions = [.withInternetDateTime]
            date = isoFormatter.date(from: createdAt)
        }
        guard let parsedDate = date else { return "" }

        let now = Date()
        let diff = now.timeIntervalSince(parsedDate)

        if diff < 60 { return "刚刚" }
        if diff < 3600 { return "\(Int(diff / 60))分钟前" }
        if diff < 86400 { return "\(Int(diff / 3600))小时前" }
        if diff < 604800 { return "\(Int(diff / 86400))天前" }

        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: parsedDate)
    }

    /// 分析类型标签
    var analysisTypeLabel: String {
        isBatch ? "批量分析" : "单篇分析"
    }

    /// 总体评分（从分析文本中提取）
    var overallScore: Int? {
        nil
    }

    /// 摘要（分析文本的前100字）
    var summary: String? {
        let text = analysis.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { return nil }
        if text.count <= 100 { return text }
        return String(text.prefix(100)) + "..."
    }

    /// 完整分析结果
    var result: String? {
        let text = analysis.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }
}

/// 日记快照（可以是单个或数组）
enum DiaryAnalysisSnapshot: Codable {
    case single(DiarySnapshotItem)
    case batch([DiarySnapshotItem])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        // 先尝试解析为数组
        if let array = try? container.decode([DiarySnapshotItem].self) {
            self = .batch(array)
        } else if let single = try? container.decode(DiarySnapshotItem.self) {
            self = .single(single)
        } else {
            throw DecodingError.typeMismatch(
                DiaryAnalysisSnapshot.self,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected single or array")
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .single(let item):
            try container.encode(item)
        case .batch(let items):
            try container.encode(items)
        }
    }

    /// 获取标题摘要
    var titleSummary: String {
        switch self {
        case .single(let item):
            return item.title ?? "无标题"
        case .batch(let items):
            return items.prefix(3).compactMap { $0.title ?? "无标题" }.joined(separator: "、")
        }
    }
}

/// 日记快照项
struct DiarySnapshotItem: Codable {
    let title: String?
    let content: String?
    let mood: String?
    let weather: String?
    let createdAt: String?

    var moodEmoji: String {
        DiaryData.moodOptions.first { $0.value == mood }?.emoji ?? "😊"
    }

    var weatherEmoji: String {
        DiaryData.weatherOptions.first { $0.value == weather }?.emoji ?? "☀️"
    }

    /// 转换为字典（用于 AnyCodable 编码）
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        if let title = title { dict["title"] = title }
        if let content = content { dict["content"] = content }
        if let mood = mood { dict["mood"] = mood }
        if let weather = weather { dict["weather"] = weather }
        if let createdAt = createdAt { dict["createdAt"] = createdAt }
        return dict
    }
}

// MARK: - AI 分析 API 请求

/// 单条日记分析请求
struct AnalyzeDiaryRequest: Encodable {
    let diaryId: String?
    let content: String
    let title: String?
    let mood: String?
    let weather: String?
    let createdAt: String?
}

/// 批量日记分析请求
struct AnalyzeDiariesBatchRequest: Encodable {
    let diaries: [DiaryBatchItem]
    let period: String  // "this_week" | "last_week"
}

/// 批量分析的日记项
struct DiaryBatchItem: Encodable {
    let title: String?
    let content: String
    let mood: String?
    let weather: String?
    let createdAt: String?
}

/// 保存分析记录请求
/// 注意: AnyCodable 类型已移至 Core/Models/AnyCodable.swift
struct SaveDiaryAnalysisRequest: Encodable {
    let isBatch: Bool
    let period: String?
    let diaryId: String?
    let diaryIds: [String]?
    let diaryCount: Int
    let diarySnapshot: AnyCodable
    let analysis: String
    let modelName: String?
    let tokensUsed: Int?
    let responseTime: Int?
}

// MARK: - AI 分析 API 响应

/// 单条/批量分析响应
struct DiaryAnalysisResponse: Decodable {
    let success: Bool
    let data: DiaryAnalysisResultData?
    let error: String?
}

struct DiaryAnalysisResultData: Decodable {
    let analysis: String
    let modelName: String?
    let period: String?
    let diaryCount: Int?
    let tokensUsed: Int?
    let responseTime: Int?
}

/// 分析历史列表响应
struct DiaryAnalysisHistoryResponse: Decodable {
    let success: Bool
    let data: DiaryAnalysisHistoryData?
    let error: String?
}

struct DiaryAnalysisHistoryData: Decodable {
    let records: [DiaryAnalysisData]
    let pagination: DiaryPagination
}

/// 保存分析响应
struct SaveDiaryAnalysisResponse: Decodable {
    let success: Bool
    let data: DiaryAnalysisData?
    let error: String?
}

/// 删除分析响应
struct DeleteDiaryAnalysisResponse: Decodable {
    let success: Bool
    let message: String?
    let error: String?
}

// MARK: - AI 分析加载文本

enum DiaryAILoadingTexts {
    static let texts: [String] = [
        "GPU 正在预热...",
        "AI 正在起床...",
        "模型正在加载...",
        "正在查看日记...",
        "正在猜测错别字的意思...",
        "正在分析小朋友的心情...",
        "正在数字数...",
        "正在理解童言童语...",
        "正在思考如何夸奖...",
        "正在寻找闪光点...",
        "正在分析写作风格...",
        "正在回忆自己小时候...",
        "正在组织温暖的语言...",
        "正在计算情感指数...",
        "神经网络运算中...",
        "正在翻阅育儿手册...",
        "正在生成鼓励的话..."
    ]

    static func random() -> String {
        texts.randomElement() ?? "AI 正在分析中..."
    }
}
