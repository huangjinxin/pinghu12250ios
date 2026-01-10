//
//  Child.swift
//  pinghu12250
//
//  孩子数据模型（家长视角）
//

import Foundation

/// 孩子信息模型
struct Child: Codable, Identifiable, Hashable {
    let id: String
    let username: String
    let email: String?
    let avatar: String?
    let totalPoints: Int?
    let createdAt: String?
    let profile: ChildProfile?
    let `class`: ChildClass?

    /// 统计数据
    var stats: ChildStats?

    /// 最近动态
    var recentActivities: [ChildActivity]?

    /// 显示名称
    var displayName: String {
        profile?.nickname ?? username
    }

    /// 头像字母
    var avatarLetter: String {
        String(displayName.prefix(1))
    }

    /// 头像URL
    var avatarURL: URL? {
        guard let avatar = avatar else { return nil }
        if avatar.hasPrefix("http") {
            return URL(string: avatar)
        }
        return URL(string: APIConfig.baseURL.replacingOccurrences(of: "/api", with: "") + avatar)
    }

    // Hashable 实现
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: Child, rhs: Child) -> Bool {
        lhs.id == rhs.id
    }
}

/// 孩子资料
struct ChildProfile: Codable {
    let id: String?
    let userId: String?
    let nickname: String?
    let bio: String?
    let grade: String?
    let interests: [String]?
    let joinedDays: Int?
    let profilePublic: Bool?
    let showStats: Bool?
    let createdAt: String?
    let updatedAt: String?

    // 便捷初始化（用于 Preview 和测试）
    init(
        id: String? = nil,
        userId: String? = nil,
        nickname: String? = nil,
        bio: String? = nil,
        grade: String? = nil,
        interests: [String]? = nil,
        joinedDays: Int? = nil,
        profilePublic: Bool? = nil,
        showStats: Bool? = nil,
        createdAt: String? = nil,
        updatedAt: String? = nil
    ) {
        self.id = id
        self.userId = userId
        self.nickname = nickname
        self.bio = bio
        self.grade = grade
        self.interests = interests
        self.joinedDays = joinedDays
        self.profilePublic = profilePublic
        self.showStats = showStats
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// 孩子班级信息
struct ChildClass: Codable {
    let id: String?
    let name: String?
    let school: ChildSchool?
}

/// 学校信息
struct ChildSchool: Codable {
    let id: String?
    let name: String?
}

/// 孩子统计数据
struct ChildStats: Codable {
    let totalPoints: Int?
    let learningCoins: FlexibleDouble?  // API 返回 String 如 "5.11"
    let worksCount: Int?
    let htmlWorksCount: Int?
    let poetryWorksCount: Int?
    let submissionsCount: Int?
    let joinedDays: Int?
}

/// 孩子动态
struct ChildActivity: Codable, Identifiable {
    let id: String
    let type: String
    let title: String
    let description: String?
    let points: Int?
    let amount: Double?  // API 返回的金额字段
    let createdAt: String
}

/// 获取孩子列表的响应
struct ChildrenResponse: Decodable {
    let children: [Child]
}
