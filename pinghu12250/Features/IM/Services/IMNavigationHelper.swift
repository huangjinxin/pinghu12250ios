//
//  IMNavigationHelper.swift
//  pinghu12250
//
//  IM 导航辅助 — 所有页面通过这里触发 IM 动作
//  内部只发通知，不做 createOrGet（由 IMCoordinator 处理）
//

import Foundation

enum IMNavigationHelper {
    /// 请求打开指定好友的 IM 会话
    static func openFriendChat(userId: String) {
        NotificationCenter.default.post(
            name: .openConversation,
            object: nil,
            userInfo: ["userId": userId]
        )
    }

    /// 请求打开指定 Bot 会话
    static func openBotChat(botId: String) {
        NotificationCenter.default.post(
            name: .openBotConversation,
            object: nil,
            userInfo: ["botId": botId]
        )
    }

    /// 通知好友关系变更
    static func notifyFriendAdded() {
        NotificationCenter.default.post(name: .friendAdded, object: nil)
    }
}
