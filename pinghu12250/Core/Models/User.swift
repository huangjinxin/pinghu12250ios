//
//  User.swift
//  pinghu12250
//
//  用户模型
//

import Foundation
import SwiftUI

/// 用户角色
enum UserRole: String, Codable, CaseIterable {
    case student = "STUDENT"
    case parent = "PARENT"
    case teacher = "TEACHER"
    case admin = "ADMIN"

    var displayName: String {
        switch self {
        case .student: return "学生"
        case .parent: return "家长"
        case .teacher: return "老师"
        case .admin: return "管理员"
        }
    }

    var label: String {
        displayName
    }

    var color: Color {
        switch self {
        case .student: return .green
        case .parent: return .blue
        case .teacher: return .orange
        case .admin: return .red
        }
    }
}

/// 用户资料
struct UserProfile: Codable {
    let id: String?
    let userId: String?
    let nickname: String?
    let bio: String?
    let grade: String?
    let interests: [String]?
    let joinedDays: Int?
    let profilePublic: Bool?
    let showStats: Bool?
}

/// 用户模型
struct User: Codable, Identifiable {
    let id: String
    let username: String
    let email: String?
    let nickname: String?
    let avatar: String?
    let role: UserRole
    let bio: String?
    let totalPoints: Int?
    let coins: Int?
    let createdAt: String?
    let updatedAt: String?
    let profile: UserProfile?

    // 新增字段（API 返回但之前未定义）
    let paymentPassword: String?
    let status: String?
    let schoolId: String?
    let classId: String?
    let lastLoginDate: String?
    let loginStreakDays: Int?
    let followersCount: Int?
    let followingCount: Int?
    let friendsCount: Int?
    let avatarChar: String?

    // 两步验证 (2FA)
    let twoFactorEnabled: Bool?
    let twoFactorEnabledAt: String?

    // 兼容性字段
    var points: Int? { totalPoints }

    /// 显示名称（优先 profile.nickname，其次 nickname，最后 username）
    var displayName: String {
        profile?.nickname ?? nickname ?? username
    }

    /// 头像字母（用于默认头像显示）
    var avatarLetter: String {
        String(displayName.prefix(1))
    }

    /// 头像 URL
    var avatarURL: URL? {
        guard let avatar = avatar else { return nil }
        if avatar.hasPrefix("http") {
            return URL(string: avatar)
        }
        return URL(string: APIConfig.baseURL.replacingOccurrences(of: "/api", with: "") + avatar)
    }
}

/// 登录请求
struct LoginRequest: Encodable {
    let username: String
    let password: String
}

/// 登录响应
struct LoginResponse: Decodable {
    let token: String?
    let user: User?
    let message: String?       // API 返回的消息
    let loginPoints: Int?      // 登录获得的积分
    // 两步验证 (2FA) 响应字段
    let requiresTwoFactor: Bool?
    let tempToken: String?
}

/// 两步验证请求
struct TwoFactorVerifyRequest: Encodable {
    let tempToken: String
    let code: String
}

/// 两步验证响应
struct TwoFactorVerifyResponse: Decodable {
    let token: String
    let user: User
    let message: String?
    let usedBackupCode: Bool?
    let remainingBackupCodes: Int?
}

/// 注册请求
struct RegisterRequest: Encodable {
    let username: String
    let password: String
    let email: String?
    let nickname: String?
    let role: String
}

/// 删除账户请求
struct DeleteAccountRequest: Encodable {
    let password: String
}

/// 删除账户响应
struct DeleteAccountResponse: Decodable {
    let success: Bool
    let message: String?
}
