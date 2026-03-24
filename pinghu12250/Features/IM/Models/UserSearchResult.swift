//
//  UserSearchResult.swift
//  pinghu12250
//
//  用户搜索结果模型
//

import Foundation

struct UserSearchResult: Codable, Identifiable {
    let id: String
    let username: String
    let nickname: String?
    let avatar: String?
    let role: UserRole
    let isFriend: Bool
    let requestStatus: String // "NONE", "SENT", "RECEIVED"

    var displayName: String {
        nickname ?? username
    }
}
