//
//  ContactsViewModel.swift
//  pinghu12250
//
//  通讯录视图模型
//

import SwiftUI
import Combine

@MainActor
class ContactsViewModel: ObservableObject {
    @Published var aiAssistants: [ContactItem] = []
    @Published var teachers: [ContactItem] = []
    @Published var classmates: [ContactItem] = []
    @Published var parents: [ContactItem] = []
    @Published var friends: [User] = []

    func loadContacts() {
        Task {
            await loadRealFriends()
            loadBots()
        }
    }

    private func loadRealFriends() async {
        do {
            friends = try await FriendService.shared.getFriends()
            print("✅ ContactsView 加载好友: \(friends.count) 个")
        } catch {
            print("❌ ContactsView 加载好友失败: \(error)")
        }
    }

    private func loadBots() {
        // AI助手从服务器加载
        Task {
            do {
                let response: APIResponse<[Bot]> = try await APIService.shared.get("/api/bot")
                if let bots = response.data {
                    aiAssistants = bots.map { bot in
                        ContactItem(
                            id: bot.id,
                            name: bot.name,
                            subtitle: bot.description ?? "助手",
                            role: .ai
                        )
                    }
                }
            } catch {
                print("加载 Bot 失败: \(error)")
            }
        }
    }
}
