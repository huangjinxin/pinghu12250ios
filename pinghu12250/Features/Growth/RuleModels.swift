//
//  RuleModels.swift
//  pinghu12250
//
//  奖罚规则相关数据模型
//

import SwiftUI

// MARK: - 规则类型

struct RuleType: Codable, Identifiable {
    let id: String
    let name: String
    let description: String?
    let isEnabled: Bool?
    let createdAt: String?
}

// MARK: - 展示标准

struct RuleStandard: Codable, Identifiable {
    let id: String
    let name: String
    let description: String?
    let isEnabled: Bool?
    let createdAt: String?
}

// MARK: - 规则模板

struct RuleTemplate: Codable, Identifiable {
    let id: String
    let name: String
    let description: String?
    let points: Int
    let typeId: String?
    let standardId: String?
    let requireText: Bool
    let requireImage: Bool
    let requireLink: Bool
    let requireAudio: Bool?
    let textMaxLength: Int?
    let audioUrl: String?
    let allowQuantity: Bool?
    let status: String?
    let createdAt: String?
    let type: RuleType?
    let standard: RuleStandard?

    // 用于收藏状态
    var isFavorite: Bool?
    var favoriteId: String?
}

// MARK: - 提交记录

struct RuleSubmission: Codable, Identifiable {
    let id: String
    let userId: String
    let templateId: String
    let content: String?
    let images: [String]?
    let audios: [String]?
    let link: String?
    let quantity: Int?
    let status: String
    let reviewNote: String?
    let reviewedAt: String?
    let pointsAwarded: Int?
    let createdAt: String?
    let updatedAt: String?
    let template: RuleTemplate?
    let user: SimpleUser?
    let reviewer: SimpleUser?

    // 状态显示
    var statusText: String {
        switch status {
        case "PENDING": return "待审核"
        case "APPROVED": return "已通过"
        case "REJECTED": return "已拒绝"
        default: return status
        }
    }

    var statusColor: Color {
        switch status {
        case "PENDING": return .orange
        case "APPROVED": return .green
        case "REJECTED": return .red
        default: return .secondary
        }
    }
}

// MARK: - API 响应模型
// 注意: SimpleUser, PaginationInfo, UploadResponse, MessageResponse 已移至 Core/Models/CommonTypes.swift

struct TemplatesResponse: Decodable {
    let templates: [RuleTemplate]
}

struct SubmissionsResponse: Decodable {
    let submissions: [RuleSubmission]
    let pagination: PaginationInfo?
}

struct FavoritesResponse: Decodable {
    let templates: [RuleTemplate]
    let pagination: PaginationInfo?
}

struct CheckFavoritesResponse: Decodable {
    let favorites: [String: Bool]
}

struct SubmissionResponse: Decodable {
    let submission: RuleSubmission
}

struct FavoriteResponse: Decodable {
    let favorite: TemplateFavorite?
    let message: String?
}

struct TemplateFavorite: Codable {
    let id: String
    let userId: String
    let templateId: String
    let createdAt: String?
}

// MARK: - 创建提交请求

struct CreateSubmissionRequest: Encodable {
    let templateId: String
    let content: String?
    let images: [String]?
    let audios: [String]?
    let link: String?
    let quantity: Int?
}
