//
//  PhotosModels.swift
//  pinghu12250
//
//  照片分享数据模型 - 对应 Web 端 Photos.vue
//

import Foundation
import SwiftUI

// MARK: - 照片作者

struct PhotoAuthor: Codable {
    let id: String
    let username: String
    let avatar: String?
    let profile: PhotoAuthorProfile?

    var displayName: String {
        profile?.nickname ?? username
    }

    var avatarLetter: String {
        String((profile?.nickname ?? username).prefix(1))
    }
}

struct PhotoAuthorProfile: Codable {
    let nickname: String?
}

// MARK: - 照片项

struct PhotoItem: Codable, Identifiable {
    let id: String
    let content: String?
    let images: [String]
    let mood: String?
    let moodScore: Int?
    let photoType: String?
    let location: String?
    let isPublic: Bool?
    let author: PhotoAuthor?
    let likesCount: Int
    let commentsCount: Int
    let isLiked: Bool
    let createdAt: String
    var comments: [PhotoComment]?

    /// 第一张图片的完整 URL
    var fullImageURL: String? {
        buildFullURL(images.first)
    }

    /// 所有图片的完整 URL
    var allFullImageURLs: [String] {
        images.compactMap { buildFullURL($0) }
    }

    /// 相对时间
    var relativeTime: String {
        guard let date = ISO8601DateFormatter().date(from: createdAt) else {
            return String(createdAt.prefix(10)).replacingOccurrences(of: "-", with: "/")
        }

        let now = Date()
        let diff = now.timeIntervalSince(date)

        if diff < 60 { return "刚刚" }
        if diff < 3600 { return "\(Int(diff / 60))分钟前" }
        if diff < 86400 { return "\(Int(diff / 3600))小时前" }
        if diff < 604800 { return "\(Int(diff / 86400))天前" }

        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }
}

// MARK: - 照片评论

struct PhotoComment: Codable, Identifiable {
    let id: String
    let content: String
    let author: PhotoAuthor?
    let createdAt: String
}

// MARK: - API 响应

struct PhotoListResponse: Decodable {
    let success: Bool
    let data: [PhotoItem]
    let pagination: PhotoPaginationInfo?
}

struct PhotoPaginationInfo: Decodable {
    let page: Int
    let total: Int
    let totalPages: Int
    let limit: Int?
}

struct PhotoDetailResponse: Decodable {
    let success: Bool
    let data: PhotoItem
}

struct PhotoPublishResponse: Decodable {
    let success: Bool
    let data: PhotoItem?
    let error: String?
}

struct PhotoLikeResponse: Decodable {
    let success: Bool
    let liked: Bool
}

struct PhotoCommentResponse: Decodable {
    let success: Bool
    let data: PhotoComment?
    let error: String?
}
