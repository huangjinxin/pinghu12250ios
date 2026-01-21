//
//  WritingModels.swift
//  pinghu12250
//
//  书写功能数据模型
//

import Foundation

// MARK: - 字体模型

struct UserFont: Codable, Identifiable {
    let id: String
    let userId: String?
    let name: String?
    let originalName: String?
    let fontFamily: String?
    let filePath: String?
    let fileSize: Int?
    let isDefault: Bool?
    let createdAt: String?

    var displayName: String {
        if let n = name, !n.isEmpty { return n }
        return originalName ?? "未命名字体"
    }
}

// MARK: - 书写作品

struct CalligraphyWork: Codable, Identifiable {
    let id: String
    let authorId: String?
    let title: String?
    let content: CalligraphyContent?
    let preview: String?
    let charCount: Int?
    let fontId: String?
    let evaluationScore: Int?
    let evaluationData: EvaluationDetailData?
    let likesCount: Int?
    let isLiked: Bool?
    let createdAt: String
    let author: WorkAuthor?

    var displayTitle: String {
        if let t = title, !t.isEmpty { return t }
        if let c = content {
            return c.characters.joined()
        }
        return ""
    }

    var likeCount: Int { likesCount ?? 0 }

    struct WorkAuthor: Codable {
        let id: String
        let username: String
        let avatar: String?
        let profile: AuthorProfile?

        struct AuthorProfile: Codable {
            let nickname: String?
        }

        var displayName: String {
            profile?.nickname ?? username
        }
    }
}

// 作品内容（新格式：每个字单独存储）
struct CalligraphyContent: Codable {
    let characters: [String]
    let previews: [String?]
    let strokeDataList: [StrokeDataV2?]

    init(from decoder: Decoder) throws {
        // 尝试解析为数组格式 [{character, preview, strokeData}]
        if let container = try? decoder.singleValueContainer(),
           let items = try? container.decode([ContentItem].self) {
            self.characters = items.map { $0.character }
            self.previews = items.map { $0.preview }
            self.strokeDataList = items.map { $0.strokeData }
        } else {
            self.characters = []
            self.previews = []
            self.strokeDataList = []
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        let items = zip(zip(characters, previews), strokeDataList).map {
            ContentItem(character: $0.0, preview: $0.1, strokeData: $1)
        }
        try container.encode(items)
    }

    struct ContentItem: Codable {
        let character: String
        let preview: String?
        let strokeData: StrokeDataV2?
    }
}

// MARK: - AI评分数据

struct EvaluationData: Codable {
    let score: Int?
    let comment: String?
    let details: EvaluationDetails?

    struct EvaluationDetails: Codable {
        let structure: Int?
        let stroke: Int?
        let balance: Int?
        let overall: Int?
    }
}

struct EvaluationDetailData: Codable {
    let recognition: ScoreItem?
    let strokeQuality: ScoreItem?
    let aesthetics: ScoreItem?
    let summary: String?

    struct ScoreItem: Codable {
        let score: Int?
    }
}

// MARK: - 创建请求

struct CreateCalligraphyRequest: Codable {
    let content: String
    let fontId: String?
    let imagePath: String?
    let strokeData: String?
}

// MARK: - API响应

struct FontListResponse: Codable {
    let success: Bool
    let data: [UserFont]?
    let error: String?
}

struct FontResponse: Codable {
    let success: Bool
    let data: UserFont?
    let error: String?
}

struct CalligraphyListResponse: Codable {
    let success: Bool
    let data: CalligraphyListData?
    let error: String?

    struct CalligraphyListData: Codable {
        let works: [CalligraphyWork]
        let total: Int
        let totalPages: Int
        let page: Int?
        let limit: Int?
    }
}

struct CalligraphyResponse: Codable {
    let success: Bool
    let data: CalligraphyWork?
    let error: String?
}

struct LikeResponse: Codable {
    let success: Bool
    let data: LikeData?
    let error: String?

    struct LikeData: Codable {
        let liked: Bool
        let likeCount: Int
    }
}
