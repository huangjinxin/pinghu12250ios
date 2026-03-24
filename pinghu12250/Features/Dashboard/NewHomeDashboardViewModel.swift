//
//  NewHomeDashboardViewModel.swift
//  pinghu12250
//
//  首页数据管理
//

import SwiftUI
import Combine

@MainActor
class NewHomeDashboardViewModel: ObservableObject {
    @Published var tasks: [TaskItem] = []
    @Published var leaderboards: [(key: String, icon: String, title: String, color: Color, items: [LeaderboardItem])] = []
    @Published var isLoading = false

    private let api = APIService.shared

    func loadData() async {
        isLoading = true
        defer { isLoading = false }

        await loadTasks()
        await loadLeaderboards()
    }

    private func loadTasks() async {
        let configs: [(id: String, name: String, icon: String, points: Int, bg: Color)] = [
            ("diary", "日记", "📖", 200, Color.purple.opacity(0.1)),
            ("math", "数学", "🔢", 60, Color.blue.opacity(0.1)),
            ("poetry", "背诗", "📰", 55, Color.orange.opacity(0.1)),
            ("calligraphy", "书写", "✏️", 50, Color.pink.opacity(0.1)),
            ("moments", "分享生活", "📷", 3, Color.teal.opacity(0.1)),
            ("questions", "勤学好问", "❓", 3, Color.purple.opacity(0.1))
        ]

        tasks = configs.map { TaskItem(id: $0.id, name: $0.name, icon: $0.icon, points: $0.points, status: .pending, bgColor: $0.bg) }
    }

    private func loadLeaderboards() async {
        let dimensions: [(key: String, icon: String, title: String, color: Color)] = [
            ("points", "⭐", "积分排行", .blue),
            ("diary", "📖", "日记字数", .purple),
            ("streak", "🔥", "连续打卡", .orange),
            ("learning", "📚", "学习任务", .blue),
            ("works", "🎨", "作品数量", .pink),
            ("questions", "❓", "提问互动", .purple)
        ]

        var results: [(key: String, icon: String, title: String, color: Color, items: [LeaderboardItem])] = []

        for dim in dimensions {
            do {
                let response: APIResponse<FeedLeaderboardResponse> = try await api.get("/api/feed/leaderboard?dimension=\(dim.key)&period=weekly&limit=5")
                let entries = response.data?.leaderboard ?? []
                let items = entries.enumerated().map { index, entry -> LeaderboardItem in
                    let rank = index + 1
                    let name = entry.user?.profile?.nickname ?? entry.user?.username ?? "?"
                    let value = entry.value ?? 0
                    let label = entry.label ?? ""
                    return LeaderboardItem(rank: rank, name: name, value: value, label: label)
                }
                results.append((dim.key, dim.icon, dim.title, dim.color, items))
            } catch {
                results.append((dim.key, dim.icon, dim.title, dim.color, []))
            }
        }

        leaderboards = results
    }
}

struct FeedLeaderboardResponse: Codable {
    let leaderboard: [FeedLeaderboardEntry]?
}

struct FeedLeaderboardEntry: Codable {
    let user: FeedLeaderboardUser?
    let value: Int?
    let label: String?
}

struct FeedLeaderboardUser: Codable {
    let username: String?
    let profile: FeedLeaderboardProfile?
}

struct FeedLeaderboardProfile: Codable {
    let nickname: String?
}
