//
//  FriendService.swift
//  pinghu12250
//
//  好友服务
//

import Foundation

struct FriendRequestResult: Decodable {
    let id: String
    let status: String
    let autoAccepted: Bool?
}

@MainActor
class FriendService {
    static let shared = FriendService()
    private let api = APIService.shared

    // 搜索用户
    func searchUsers(query: String) async throws -> [UserSearchResult] {
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            return []
        }
        let endpoint = "\(APIConfig.Endpoints.users)/search?q=\(encodedQuery)"
        let resp: APIResponse<[UserSearchResult]> = try await api.get(endpoint)
        return resp.data ?? []
    }

    // 发送好友请求（返回结果）
    func sendFriendRequestWithResult(toUserId: String) async throws -> APIResponse<FriendRequestResult> {
        let body = ["toUserId": toUserId]
        return try await api.post(APIConfig.Endpoints.friendRequests, body: body)
    }

    // 发送好友请求
    func sendFriendRequest(toUserId: String) async throws {
        let body = ["toUserId": toUserId]
        let _: APIResponse<String?> = try await api.post(APIConfig.Endpoints.friendRequests, body: body)
    }

    // 获取用户详情
    func getUserById(_ userId: String) async throws -> User {
        try await api.get("\(APIConfig.Endpoints.users)/\(userId)")
    }

    // 获取好友列表
    func getFriends() async throws -> [User] {
        let resp: APIResponse<[User]> = try await api.get("\(APIConfig.Endpoints.follows)/friends")
        print("🔍 好友接口返回: success=\(resp.success ?? false), data count=\(resp.data?.count ?? 0)")
        if let data = resp.data {
            print("📋 好友原始数据: \(data.map { "\($0.username) (id:\($0.id))" })")
        }
        return resp.data ?? []
    }
}
