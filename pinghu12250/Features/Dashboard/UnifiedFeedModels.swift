//
//  UnifiedFeedModels.swift
//  pinghu12250
//
//  统一动态 Feed 数据模型 - 对应 Web 端 MomentsCarousel
//

import Foundation

// MARK: - 统一动态 Feed 响应

struct UnifiedFeedResponse: Codable {
    let success: Bool
    let data: UnifiedFeedData?
    let error: String?
}

struct UnifiedFeedData: Codable {
    let items: [UnifiedFeedItem]
    let pagination: FeedPagination
}

struct FeedPagination: Codable {
    let page: Int
    let limit: Int
    let total: Int
    let totalPages: Int
}

// MARK: - 统一动态项

struct UnifiedFeedItem: Codable, Identifiable {
    let id: String
    let type: FeedItemType
    let title: String?
    let content: String?
    let images: [String]?
    let mood: String?
    let photoType: String?
    let preview: String?
    let audio: String?
    let audios: [String]?
    let htmlCode: String?
    let analysis: String?
    let diarySnapshot: DiarySnapshot?
    let author: FeedAuthor
    let meta: FeedMeta?
    let likesCount: Int?
    let commentsCount: Int?
    let createdAt: String
    let link: String?

    // 获取预览图片
    var previewImage: String? {
        if let preview = preview, !preview.isEmpty {
            return preview
        }
        if let images = images, !images.isEmpty {
            return images.first
        }
        return nil
    }

    // 格式化创建时间
    var formattedTime: String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        guard let date = formatter.date(from: createdAt) else {
            // 尝试不带毫秒的格式
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: createdAt) else {
                return createdAt
            }
            return formatRelativeTime(date)
        }
        return formatRelativeTime(date)
    }

    private func formatRelativeTime(_ date: Date) -> String {
        let now = Date()
        let diff = now.timeIntervalSince(date)

        if diff < 60 {
            return "刚刚"
        } else if diff < 3600 {
            return "\(Int(diff / 60))分钟前"
        } else if diff < 86400 {
            return "\(Int(diff / 3600))小时前"
        } else {
            return "\(Int(diff / 86400))天前"
        }
    }
}

// MARK: - 动态类型枚举

enum FeedItemType: String, Codable {
    case post = "post"
    case photo = "photo"
    case gallery = "gallery"
    case recitation = "recitation"
    case diaryAnalysis = "diary-analysis"
    case poetry = "poetry"

    var displayName: String {
        switch self {
        case .post: return "动态"
        case .photo: return "照片"
        case .gallery: return "画廊"
        case .recitation: return "朗诵"
        case .diaryAnalysis: return "日记分析"
        case .poetry: return "诗词"
        }
    }

    var iconName: String {
        switch self {
        case .post: return "text.bubble.fill"
        case .photo: return "photo.fill"
        case .gallery: return "paintpalette.fill"
        case .recitation: return "mic.fill"
        case .diaryAnalysis: return "doc.text.magnifyingglass"
        case .poetry: return "book.fill"
        }
    }

    var color: String {
        switch self {
        case .post: return "#6366f1"
        case .photo: return "#ec4899"
        case .gallery: return "#8b5cf6"
        case .recitation: return "#f59e0b"
        case .diaryAnalysis: return "#10b981"
        case .poetry: return "#3b82f6"
        }
    }
}

// MARK: - 作者信息

struct FeedAuthor: Codable {
    let id: String
    let name: String
    let avatar: String?

    var avatarLetter: String {
        name.first.map(String.init) ?? "用"
    }
}

// MARK: - 元数据

struct FeedMeta: Codable {
    // 画廊/朗诵
    let typeName: String?
    let standardName: String?

    // 日记分析
    let grade: String?
    let totalScore: Int?
    let diaryCount: Int?
    let isBatch: Bool?
    let period: String?
    let modelName: String?
    let tokensUsed: Int?

    // 诗词
    let category: String?
    let categorySlug: String?
    let categoryIcon: String?
}

// MARK: - 日记快照

struct DiarySnapshot: Codable {
    let title: String?
    let content: String?
    let mood: String?
    let weather: String?
    let createdAt: String?
}

// MARK: - 心情映射

struct MoodHelper {
    static let emojis: [String: String] = [
        "happy": "😄",
        "excited": "🤩",
        "calm": "😊",
        "sad": "😢",
        "angry": "😠",
        "anxious": "😰"
    ]

    static func emoji(for mood: String?) -> String {
        guard let mood = mood else { return "" }
        return emojis[mood] ?? ""
    }
}
