//
//  WorksModels.swift
//  pinghu12250
//
//  作品广场数据模型 - 画廊/朗诵/唐诗宋词/购物
//

import Foundation
import SwiftUI

// MARK: - URL 工具

/// 将相对路径转换为完整 URL
func buildFullURL(_ relativePath: String?) -> String? {
    guard let path = relativePath, !path.isEmpty else { return nil }

    // 如果已经是完整 URL，直接返回
    if path.hasPrefix("http://") || path.hasPrefix("https://") {
        return path
    }

    // 获取服务器基础地址（去掉 /api 后缀）
    let baseURL = ServerConfig.shared.currentURL.replacingOccurrences(of: "/api", with: "")

    // 拼接完整 URL
    if path.hasPrefix("/") {
        return baseURL + path
    } else {
        return baseURL + "/" + path
    }
}

// MARK: - 作者信息

struct WorkAuthor: Codable {
    let id: String
    let username: String
    let nickname: String?  // 直接的 nickname 字段
    let avatar: String?
    let profile: WorkAuthorProfile?  // 嵌套的 profile 对象

    var displayName: String {
        nickname ?? profile?.nickname ?? username
    }

    var avatarLetter: String {
        String((nickname ?? profile?.nickname ?? username).prefix(1))
    }

    enum CodingKeys: String, CodingKey {
        case id, username, nickname, avatar, profile
    }
}

struct WorkAuthorProfile: Codable {
    let nickname: String?
}

// MARK: - 画廊作品

struct GalleryWork: Codable, Identifiable {
    let id: String
    let image: String?
    let images: [String]?
    let content: String?
    let author: WorkAuthor?
    let template: GalleryTemplate?
    let createdAt: String?

    var displayImage: String? {
        image ?? images?.first
    }

    /// 完整的显示图片 URL（自动添加服务器地址）
    var fullImageURL: String? {
        buildFullURL(displayImage)
    }

    var allImages: [String] {
        if let images = images, !images.isEmpty {
            return images
        }
        if let image = image {
            return [image]
        }
        return []
    }

    /// 所有图片的完整 URL
    var allFullImageURLs: [String] {
        allImages.compactMap { buildFullURL($0) }
    }
}

struct GalleryTemplate: Codable {
    let id: String
    let name: String
    let type: GalleryType?
    let standard: GalleryStandard?
}

struct GalleryType: Codable, Identifiable {
    let id: String
    let name: String
}

struct GalleryStandard: Codable, Identifiable {
    let id: String
    let name: String
}

struct GalleryResponse: Decodable {
    let works: [GalleryWork]
    let pagination: PaginationInfo?
}

struct GalleryDetailResponse: Decodable {
    let work: GalleryWork
}

struct GalleryTypesResponse: Decodable {
    let types: [GalleryType]
}

struct GalleryStandardsResponse: Decodable {
    let standards: [GalleryStandard]
}

// MARK: - 朗诵作品

struct RecitationWork: Codable, Identifiable {
    let id: String
    let audio: String?
    let audios: [String]?
    let content: String?
    let author: WorkAuthor?
    let template: GalleryTemplate?
    let createdAt: String?

    var displayAudio: String? {
        audio ?? audios?.first
    }

    /// 完整的显示音频 URL
    var fullAudioURL: String? {
        buildFullURL(displayAudio)
    }

    var allAudios: [String] {
        if let audios = audios, !audios.isEmpty {
            return audios
        }
        if let audio = audio {
            return [audio]
        }
        return []
    }

    /// 所有音频的完整 URL
    var allFullAudioURLs: [String] {
        allAudios.compactMap { buildFullURL($0) }
    }
}

struct RecitationResponse: Decodable {
    let works: [RecitationWork]
    let pagination: PaginationInfo?
}

struct RecitationDetailResponse: Decodable {
    let work: RecitationWork
}

// MARK: - 唐诗宋词作品

struct PoetryWorkData: Codable, Identifiable {
    let id: String
    let title: String
    let htmlCode: String?
    let coverImage: String?  // 封面图片路径
    let status: String?
    let reviewReason: String?
    let createdAt: String?
    let updatedAt: String?
    let authorId: String?
    let author: WorkAuthor?
    let likesCount: Int?

    enum CodingKeys: String, CodingKey {
        case id, title, status, author
        case htmlCode = "htmlCode"
        case coverImage = "coverImage"
        case reviewReason = "reviewReason"
        case createdAt = "createdAt"
        case updatedAt = "updatedAt"
        case authorId = "authorId"
        case likesCount = "likesCount"
    }

    var isApproved: Bool {
        status == "APPROVED"
    }

    /// 完整的封面图片 URL
    var fullCoverImageURL: String? {
        buildFullURL(coverImage)
    }
}

struct PoetryResponse: Decodable {
    let works: [PoetryWorkData]
    let pagination: PaginationInfo?
}

struct PoetryDetailResponse: Decodable {
    let work: PoetryWorkData
}

struct PoetryLikeRequest: Encodable {
    let isLike: Bool
}

// MARK: - 市场商品

struct MarketWork: Codable, Identifiable {
    let id: String
    let title: String
    let description: String?
    let price: Double
    let seller: WorkAuthor?
    let htmlContent: String?
    let cssContent: String?
    let jsContent: String?
    let sales: Int?
    let isExclusive: Bool?
    let createdAt: String?
}

struct MarketResponse: Decodable {
    let works: [MarketWork]
    let pagination: PaginationInfo?
}

struct MarketDetailResponse: Decodable {
    let work: MarketWork
}

struct PurchaseRequest: Encodable {
    let workId: String
}

struct PurchaseResponse: Decodable {
    let order: MarketOrder?
    let message: String?
}

struct MarketOrder: Codable, Identifiable {
    let id: String
    let workId: String
    let buyerId: String
    let price: Double
    let status: String?
    let createdAt: String?
    let work: MarketWork?
}

struct MarketOrdersResponse: Decodable {
    let orders: [MarketOrder]
    let pagination: PaginationInfo?
}

// MARK: - QR 码商品（扫码支付）

struct QRCodeProduct: Codable, Identifiable {
    let id: String
    let code: String
    let title: String
    let description: String?
    let category: String?
    let qrcode: String?
    let createdAt: String?

    // amount 使用通用的 FlexibleDouble（定义在 Core/Models/CommonTypes.swift）
    private let _amount: FlexibleDouble

    var amount: Double {
        _amount.value
    }

    /// 完整的二维码图片 URL
    var fullQRCodeURL: String? {
        // qrcode 是 base64 data URL，直接返回
        qrcode
    }

    enum CodingKeys: String, CodingKey {
        case id, code, title, description, category, qrcode, createdAt
        case _amount = "amount"
    }
}

// 注意: AmountValue 已被 FlexibleDouble (Core/Models/CommonTypes.swift) 替代

struct QRCodeProductsResponse: Decodable {
    let codes: [QRCodeProduct]
    let pagination: PaginationInfo?
}

struct QRCategoriesResponse: Decodable {
    let categories: [String]
}

// MARK: - 排行榜

struct LeaderboardEntry: Codable, Identifiable {
    let id: String
    let userId: String
    let username: String
    let nickname: String?
    let avatar: String?
    let value: Double  // 销售额或销量
    let rank: Int

    var displayName: String {
        nickname ?? username
    }
}

struct LeaderboardResponse: Decodable {
    let entries: [LeaderboardEntry]
}

// MARK: - 公开日记分析（作品广场）

/// 日记快照（用于显示日记标题）- 本地定义避免命名冲突
struct WorksDiarySnapshot: Codable {
    let title: String?
    let content: String?
    let mood: String?
    let createdAt: String?

    enum CodingKeys: String, CodingKey {
        case title, content, mood
        case createdAt = "createdAt"
    }
}

/// 日记快照值（支持单个对象或数组）
enum DiarySnapshotValue: Codable {
    case single(WorksDiarySnapshot)
    case array([WorksDiarySnapshot])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let array = try? container.decode([WorksDiarySnapshot].self) {
            self = .array(array)
        } else if let single = try? container.decode(WorksDiarySnapshot.self) {
            self = .single(single)
        } else {
            throw DecodingError.typeMismatch(
                DiarySnapshotValue.self,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected WorksDiarySnapshot or [WorksDiarySnapshot]")
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .single(let snapshot):
            try container.encode(snapshot)
        case .array(let snapshots):
            try container.encode(snapshots)
        }
    }
}

struct PublicDiaryAnalysisItem: Codable, Identifiable {
    let id: String
    let userId: String?
    let isBatch: Bool
    let period: String?
    let diaryId: String?
    let diaryIds: [String]?
    let diaryCount: Int?
    let diarySnapshot: DiarySnapshotValue?  // 日记快照（可能是单个或数组）
    let analysis: String
    let modelName: String?
    let tokensUsed: Int?
    let responseTime: Int?
    let createdAt: String?
    let user: PublicDiaryAuthor?

    enum CodingKeys: String, CodingKey {
        case id, period, analysis, user
        case userId = "userId"
        case isBatch = "isBatch"
        case diaryId = "diaryId"
        case diaryIds = "diaryIds"
        case diaryCount = "diaryCount"
        case diarySnapshot = "diarySnapshot"
        case modelName = "modelName"
        case tokensUsed = "tokensUsed"
        case responseTime = "responseTime"
        case createdAt = "createdAt"
    }

    /// 获取日记标题（参考 Web 端 getDiaryTitle 逻辑）
    var diaryTitle: String {
        guard let snapshot = diarySnapshot else { return "日记分析" }
        switch snapshot {
        case .single(let diary):
            return diary.title ?? "无标题日记"
        case .array(let diaries):
            if diaries.isEmpty { return "日记分析" }
            if diaries.count == 1 { return diaries[0].title ?? "无标题日记" }
            return "\(diaries[0].title ?? "无标题")等\(diaries.count)篇"
        }
    }

    /// 获取分析预览（前100字符）
    var analysisPreview: String {
        let text = analysis
            .replacingOccurrences(of: "[#*`>\\[\\]()]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\n+", with: " ", options: .regularExpression)
        if text.count <= 100 { return text }
        return String(text.prefix(100)) + "..."
    }

    var displayTitle: String {
        if isBatch {
            if let period = period {
                return "\(period) 周分析"
            }
            return "批量分析 (\(diaryCount ?? 0)篇)"
        }
        return "单篇分析"
    }

    var analysisTypeLabel: String {
        isBatch ? "周分析" : "单篇"
    }

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
        let interval = now.timeIntervalSince(parsedDate)

        if interval < 60 { return "刚刚" }
        if interval < 3600 { return "\(Int(interval / 60))分钟前" }
        if interval < 86400 { return "\(Int(interval / 3600))小时前" }
        if interval < 604800 { return "\(Int(interval / 86400))天前" }

        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd"
        return formatter.string(from: parsedDate)
    }
}

struct PublicDiaryAuthor: Codable {
    let id: String
    let name: String?
    let username: String?
    let avatar: String?
    let profile: PublicDiaryProfile?

    var displayName: String {
        name ?? profile?.nickname ?? username ?? "匿名"
    }

    enum CodingKeys: String, CodingKey {
        case id, name, username, avatar, profile
    }
}

struct PublicDiaryProfile: Codable {
    let nickname: String?
}

struct PublicDiaryAnalysisResponse: Decodable {
    let records: [PublicDiaryAnalysisItem]
    let pagination: PaginationInfo?
    let authors: [PublicDiaryAuthor]?
}

// MARK: - 创意作品（动态栏目）

/// 创意作品分类（支持对象格式）
struct CreativeWorkCategory: Codable {
    let id: String?
    let name: String?
    let slug: String?
}

struct CreativeWorkItem: Codable, Identifiable {
    let id: String
    let title: String
    let content: String?
    let htmlCode: String?  // 用于诗词HTML渲染
    let coverImage: String?
    let categoryObj: CreativeWorkCategory?  // 分类对象
    let categoryStr: String?  // 分类字符串（兼容旧格式）
    let status: String?
    let likesCount: Int?
    let createdAt: String?
    let author: WorkAuthor?

    enum CodingKeys: String, CodingKey {
        case id, title, content, htmlCode, coverImage, status, likesCount, createdAt, author
        case categoryObj = "category"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        content = try container.decodeIfPresent(String.self, forKey: .content)
        htmlCode = try container.decodeIfPresent(String.self, forKey: .htmlCode)
        coverImage = try container.decodeIfPresent(String.self, forKey: .coverImage)
        status = try container.decodeIfPresent(String.self, forKey: .status)
        likesCount = try container.decodeIfPresent(Int.self, forKey: .likesCount)
        createdAt = try container.decodeIfPresent(String.self, forKey: .createdAt)
        author = try container.decodeIfPresent(WorkAuthor.self, forKey: .author)

        // 尝试解析 category 为对象或字符串
        if let catObj = try? container.decodeIfPresent(CreativeWorkCategory.self, forKey: .categoryObj) {
            categoryObj = catObj
            categoryStr = nil
        } else if let catStr = try? container.decodeIfPresent(String.self, forKey: .categoryObj) {
            categoryObj = nil
            categoryStr = catStr
        } else {
            categoryObj = nil
            categoryStr = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encodeIfPresent(content, forKey: .content)
        try container.encodeIfPresent(htmlCode, forKey: .htmlCode)
        try container.encodeIfPresent(coverImage, forKey: .coverImage)
        try container.encodeIfPresent(status, forKey: .status)
        try container.encodeIfPresent(likesCount, forKey: .likesCount)
        try container.encodeIfPresent(createdAt, forKey: .createdAt)
        try container.encodeIfPresent(author, forKey: .author)
        // 优先编码对象格式
        if let catObj = categoryObj {
            try container.encode(catObj, forKey: .categoryObj)
        } else if let catStr = categoryStr {
            try container.encode(catStr, forKey: .categoryObj)
        }
    }

    /// 获取分类名称
    var categoryName: String? {
        categoryObj?.name ?? categoryStr
    }

    var fullCoverImageURL: String? {
        buildFullURL(coverImage)
    }

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
        let interval = now.timeIntervalSince(parsedDate)

        if interval < 60 { return "刚刚" }
        if interval < 3600 { return "\(Int(interval / 60))分钟前" }
        if interval < 86400 { return "\(Int(interval / 3600))小时前" }
        if interval < 604800 { return "\(Int(interval / 86400))天前" }

        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd"
        return formatter.string(from: parsedDate)
    }
}

struct CreativeWorksResponse: Decodable {
    let works: [CreativeWorkItem]
    let pagination: PaginationInfo?
}
